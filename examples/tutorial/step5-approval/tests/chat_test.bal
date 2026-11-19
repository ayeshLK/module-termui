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

import ayesha/termui;
import ayesha/termui.term;
import ballerina/lang.runtime;
import ballerina/test;

function typed(string:Char c) returns readonly & term:KeyEvent {
    return {kind: "key", key: c, ctrl: false, alt: false};
}

function enter() returns readonly & term:KeyEvent {
    return {kind: "key", key: "enter", ctrl: false, alt: false};
}

function escape() returns readonly & term:KeyEvent {
    return {kind: "key", key: "escape", ctrl: false, alt: false};
}

// Types a question into the program by calling update directly, the way the runtime would.
function ask(Chat chat, string question) returns termui:Command? {
    foreach string:Char c in question {
        _ = chat.update(typed(c));
    }
    return chat.update(enter());
}

function rows(Chat chat) returns string[] {
    string[] result = [];
    foreach var line in chat.view() {
        string row = "";
        foreach var span in line {
            row += span.text;
        }
        result.push(row);
    }
    return result;
}

function tick(Chat chat, int times) {
    foreach int _ in 0 ..< times {
        _ = chat.update(<readonly & Tick>{kind: "tick"});
    }
}

// region gated-terminal
// A terminal that gives the program its scripted keys, and then holds back one more key (the answer to a
// question) until the screen shows the question. A key pushed up front would reach the program before the
// question existed; this one arrives when a person's would.
isolated class GatedTerminal {
    *term:Terminal;

    private final term:FakeTerminal inner;
    private final string waitFor;
    private final string:Char answer;
    private boolean given = false;

    isolated function init(term:FakeTerminal inner, string waitFor, string:Char answer) {
        self.inner = inner;
        self.waitFor = waitFor;
        self.answer = answer;
    }

    public isolated function acquire() returns error? {
        return self.inner.acquire();
    }

    public isolated function release() returns error? {
        return self.inner.release();
    }

    public isolated function size() returns term:Size|error {
        return self.inner.size();
    }

    public isolated function write(string data) returns error? {
        return self.inner.write(data);
    }

    public isolated function nextEvent() returns term:InputEvent|error? {
        term:InputEvent|error? event = self.inner.nextEvent();
        if event is () {
            boolean alreadyGiven = false;
            lock {
                alreadyGiven = self.given;
                self.given = true;
            }
            if !alreadyGiven {
                foreach int _ in 0 ..< 1000 {
                    if self.inner.screenText().includes(self.waitFor) {
                        break;
                    }
                    runtime:sleep(0.01);
                }
                return {kind: "key", key: self.answer};
            }
        }
        return event;
    }
}
// endregion gated-terminal

function askedFor(string answer) returns string|error {
    term:FakeTerminal terminal = new (100, 14);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    check termui:run(new Chat(delay = 0), new GatedTerminal(terminal, "Allow Bash", answer[0]));
    return terminal.screenText();
}

// region tests
@test:Config {}
function testApprovingRunsTheTool() returns error? {
    string screen = check askedFor("y");
    test:assertTrue(screen.includes("● Bash(bal test)"), screen);
    test:assertTrue(screen.includes("12 passed, 0 failed"), screen);
    test:assertFalse(screen.includes("denied"), "nothing was denied");
}

@test:Config {}
function testDenyingDoesNotRunTheTool() returns error? {
    string screen = check askedFor("n");
    test:assertTrue(screen.includes("denied by user"), screen);
    test:assertFalse(screen.includes("12 passed"), "the tool did not run");
}

@test:Config {}
function testWithNoTerminalTheDefaultIsToDenyAndNothingWaits() returns error? {
    term:FakeTerminal terminal = new (100, 14);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    // interactive: false is what Interface sets when nobody can answer
    check termui:run(new Chat(delay = 0), terminal, {interactive: false});
    test:assertEquals(terminal.screenLines().slice(0, 6), [
        "❯ hi",
        "You asked: hi",
        "This answer is streamed a few characters at a time.",
        "Each finished line is committed to your scrollback, and the line being written stays live.",
        "● Bash(bal test)",
        "  ⎿  denied by user"
    ]);
}

@test:Config {}
function testEscStopsTheAnswerBeforeAnyToolIsAsked() returns error? {
    term:FakeTerminal terminal = new (100, 8);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    terminal.pushKey("escape"); // handled while the model is still "thinking"
    check termui:run(new Chat(delay = 0.01), terminal, {interactive: false});
    test:assertEquals(terminal.screenLines().slice(0, 2), ["❯ hi", "⏹ Interrupted"]);
    test:assertFalse(terminal.screenText().includes("Bash"), "no tool was asked for");
}

@test:Config {}
function testTheStatusLineSaysWhenTheProgramWaitsForYou() {
    Chat chat = new (delay = 0);
    _ = ask(chat, "hi");
    _ = chat.update(<readonly & Status>{turn: 1, text: "Waiting for approval"});
    string status = rows(chat)[0];
    test:assertTrue(status.includes("Waiting for approval") && status.includes("answer below"), status);
}

@test:Config {}
function testTicksDoNotChangeTheViewWhileIdle() {
    Chat chat = new (delay = 0);
    string[] before = rows(chat);
    tick(chat, 7);
    test:assertEquals(rows(chat), before);
}

@test:Config {}
function testTheNextQuestionWorksAfterAnInterruption() {
    Chat chat = new (delay = 0);
    _ = ask(chat, "one");
    _ = chat.update(escape());
    _ = chat.update(<readonly & Done>{turn: 1, interrupted: true});
    test:assertTrue(ask(chat, "two") is termui:Command);
}
// endregion tests
