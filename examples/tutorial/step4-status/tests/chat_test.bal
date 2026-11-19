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

// region tests
@test:Config {}
function testEscStopsTheAnswerAndSaysSo() returns error? {
    term:FakeTerminal terminal = new (100, 8);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    terminal.pushKey("escape"); // handled while the model is still "thinking"
    // the input ends: the program lets the turn finish, then quits
    check termui:run(new Chat(delay = 0.01), terminal);
    string[] lines = terminal.screenLines();
    test:assertEquals(lines.slice(0, 2), ["❯ hi", "⏹ Interrupted"]);
    test:assertFalse(terminal.screenText().includes("You asked"), "no part of the answer was written");
}

@test:Config {}
function testAnUninterruptedAnswerHasNoLostOrDuplicatedLines() returns error? {
    term:FakeTerminal terminal = new (100, 8);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    check termui:run(new Chat(delay = 0), terminal);
    test:assertEquals(terminal.screenLines().slice(0, 4), [
        "❯ hi",
        "You asked: hi",
        "This answer is streamed a few characters at a time.",
        "Each finished line is committed to your scrollback, and the line being written stays live."
    ]);
}

@test:Config {}
function testTheStatusLineShowsTheSpinnerAndTheElapsedTime() {
    Chat chat = new (delay = 0);
    _ = ask(chat, "hi");
    _ = chat.update(<readonly & Status>{turn: 1, text: "Responding"});
    string status = rows(chat)[0];
    test:assertTrue(status.includes("Responding") && status.includes("0s") && status.includes("esc to interrupt"), status);
    tick(chat, 25);
    test:assertTrue(rows(chat)[0].includes("2s"), "25 ticks are 2.5 seconds");
}

@test:Config {}
function testTicksDoNotChangeTheViewWhileIdle() {
    Chat chat = new (delay = 0);
    string[] before = rows(chat);
    tick(chat, 7);
    test:assertEquals(rows(chat), before, "a quiet tick leaves the view equal, so nothing is redrawn");
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
