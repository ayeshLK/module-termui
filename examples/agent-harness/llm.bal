// Copyright (c) 2026, Ayesh Almeida.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific
// language governing permissions and limitations under the License.

// ---- Messages sent from the (fake) LLM effect to the UI program --------------------------------

type Token record {|
    "token" kind = "token";
    int turn;
    string text;
|};

type ToolStarted record {|
    "toolStarted" kind = "toolStarted";
    int turn;
    string name;
    string arg;
|};

type ToolFinished record {|
    "toolFinished" kind = "toolFinished";
    int turn;
    string name;
    string arg;
    string summary;
    boolean ok;
|};

type Status record {|
    "status" kind = "status";
    int turn;
    string text;
|};

type TurnDone record {|
    "turnDone" kind = "turnDone";
    int turn;
    boolean interrupted;
|};

// ---- A scripted "model" -------------------------------------------------------------------------

type Step record {|
    "think"|"text"|"tool" kind;
    string text = "";      // thinking label, text to stream, or tool name
    string arg = "";       // tool argument
    string result = "";    // tool result summary
    boolean approval = false;
|};

// Shared between the UI (Esc) and the streaming effect.
isolated class CancelFlag {
    private boolean set = false;

    isolated function cancel() {
        lock {
            self.set = true;
        }
    }

    isolated function isCancelled() returns boolean {
        lock {
            return self.set;
        }
    }
}

function planFor(string prompt) returns Step[] {
    string p = prompt.toLowerAscii();
    if p.includes("bug") || p.includes("fix") || p.includes("error") {
        return [
            {kind: "think", text: "Reading the code to find the cause"},
            {kind: "text", text: "I'll start by looking at where the request is handled.\n"},
            {kind: "tool", text: "Read", arg: "src/handler.bal", result: "142 lines"},
            {kind: "tool", text: "Grep", arg: "\"nil\" in src/", result: "3 matches in 2 files"},
            {kind: "text", text: "\nFound it. `parseBody` returns `()` for an empty payload and the caller " +
                "dereferences it without checking. Here is the fix:\n\n" +
                "```ballerina\n" +
                "function parseBody(http:Request req) returns json|error {\n" +
                "    json|error body = req.getJsonPayload();\n" +
                "    if body is error {\n" +
                "        return {};   // treat an empty payload as an empty object\n" +
                "    }\n" +
                "    return body;\n" +
                "}\n" +
                "```\n\n" +
                "Let me apply that change.\n"},
            {kind: "tool", text: "Edit", arg: "src/handler.bal", result: "+3 -1 lines", approval: true},
            {kind: "tool", text: "Bash", arg: "bal test", result: "12 passed, 0 failed", approval: true},
            {kind: "text", text: "\nAll 12 tests pass. The crash came from an unchecked empty payload, and " +
                "`parseBody` now returns an empty object in that case.\n"}
        ];
    }
    if p.includes("test") {
        return [
            {kind: "think", text: "Looking for existing tests"},
            {kind: "tool", text: "Glob", arg: "tests/**/*.bal", result: "4 files"},
            {kind: "text", text: "There are four test files. I'd add a case for the empty-payload path:\n\n" +
                "```ballerina\n" +
                "@test:Config {}\n" +
                "function testEmptyPayload() {\n" +
                "    test:assertEquals(parseBody(emptyRequest()), {});\n" +
                "}\n" +
                "```\n\n" +
                "Want me to add it? Just say so.\n"}
        ];
    }
    if p.includes("explain") || p.includes("what") || p.includes("how") || p.includes("why") {
        return [
            {kind: "think", text: "Thinking"},
            {kind: "text", text: "Great question. A streaming response works like this:\n\n" +
                "1. The client sends your prompt to the model API with `stream: true`.\n" +
                "2. The server answers with a series of events, each carrying a small delta of text.\n" +
                "3. The UI appends each delta as it arrives, so you can start reading before the " +
                "answer is complete.\n\n" +
                "In this app a Ballerina effect plays the role of the API: it sends one `Token` message " +
                "per word, and `update` folds each one into the live region. Finished lines are " +
                "committed to the scrollback, so they stay put while the rest keeps streaming.\n"}
        ];
    }
    return [
        {kind: "think", text: "Thinking"},
        {kind: "text", text: "Hi! I'm a dummy agent, so my answers are scripted, but the streaming is real.\n\n" +
            "Try one of these:\n" +
            "- `fix the bug in the handler` (tool calls and approval prompts)\n" +
            "- `explain how streaming works` (plain streamed text)\n" +
            "- `write a test` (a short answer with code)\n"}
    ];
}

// Splits text into word-sized chunks (keeping the trailing whitespace) to mimic LLM tokens.
isolated function chunks(string text) returns string[] {
    string[] out = [];
    string current = "";
    foreach string:Char c in text {
        current += c;
        if c == " " || c == "\n" {
            out.push(current);
            current = "";
        }
    }
    if current != "" {
        out.push(current);
    }
    return out;
}
