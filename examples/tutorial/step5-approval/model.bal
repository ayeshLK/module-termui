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

// The scripted "model" of the documentation site tutorial (steps 3 to 6). It is deliberately fake: it
// "thinks" for a moment, answers every question with the same few lines, a few characters at a time, and
// then asks to run one tool, so the interface has something to show. To connect a real model, replace what `streamAnswer` does
// inside the effect; everything around it stays the same.

import ayesha/termui;
import ballerina/lang.runtime;

// Every message carries the turn it belongs to, so a late message from an old turn is ignored.
type Status record {|
    "status" kind = "status";
    int turn;
    string text;
|};

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

type Done record {|
    "done" kind = "done";
    int turn;
    boolean interrupted;
|};

// Shared between the program (which cancels) and the effect (which checks). It is `isolated`, so both
// strands may hold it.
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

isolated function answerTo(string question) returns string {
    return "You asked: " + question + "\n" +
        "This answer is streamed a few characters at a time.\n" +
        "Each finished line is committed to your scrollback, and the line being written stays live.\n";
}

isolated function chunks(string text, int size = 3) returns string[] {
    string[] pieces = [];
    string piece = "";
    int count = 0;
    foreach string:Char c in text {
        piece += c;
        count += 1;
        if count == size {
            pieces.push(piece);
            piece = "";
            count = 0;
        }
    }
    if piece != "" {
        pieces.push(piece);
    }
    return pieces;
}

const string TOOL = "Bash";
const string TOOL_ARG = "bal test";

// The effect: it runs on its own strand and reports back only with messages.
isolated function streamAnswer(int turn, string question, decimal delay, CancelFlag flag) returns termui:EffectFunction {
    return isolated function(termui:Session session) returns error? {
        session.send({kind: "status", turn, text: "Thinking"});
        runtime:sleep(delay * 40);
        session.send({kind: "status", turn, text: "Responding"});
        boolean interrupted = false;
        foreach string piece in chunks(answerTo(question)) {
            if flag.isCancelled() || session.isStopped() {
                interrupted = true;
                break;
            }
            session.send({kind: "token", turn, text: piece});
            runtime:sleep(delay);
        }
        if !interrupted {
            check runTool(session, turn, delay);
        }
        session.send({kind: "done", turn, interrupted});
    };
}

// Asks before running the tool. `confirm` waits for the user's answer, and with no terminal to answer it
// returns the default we pass (false: deny) at once, so a script never hangs and never runs a tool nobody
// approved.
isolated function runTool(termui:Session session, int turn, decimal delay) returns error? {
    session.send({kind: "status", turn, text: "Waiting for approval"});
    boolean allowed = check session.confirm(string `Allow ${TOOL}(${TOOL_ARG})?`, false);
    if !allowed {
        session.send({kind: "toolFinished", turn, name: TOOL, arg: TOOL_ARG, summary: "denied by user", ok: false});
        return;
    }
    session.send({kind: "toolStarted", turn, name: TOOL, arg: TOOL_ARG});
    runtime:sleep(delay * 30);
    session.send({kind: "toolFinished", turn, name: TOOL, arg: TOOL_ARG, summary: "12 passed, 0 failed", ok: true});
}
