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

function ctrlC() returns term:KeyEvent {
    return {kind: "key", key: "c", ctrl: true, alt: false};
}

function typed(string:Char c) returns readonly & term:KeyEvent {
    return {kind: "key", key: c, ctrl: false, alt: false};
}

function enter() returns readonly & term:KeyEvent {
    return {kind: "key", key: "enter", ctrl: false, alt: false};
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

// region tests
@test:Config {}
function testTheAnswerIsCommittedInOrderAboveThePrompt() returns error? {
    term:FakeTerminal terminal = new (100, 8);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    // the input ends while the answer is streaming: the program lets the answer finish, then quits
    check termui:run(new Chat(delay = 0), terminal);
    string[] lines = terminal.screenLines();
    test:assertEquals(lines.slice(0, 4), [
        "❯ hi",
        "You asked: hi",
        "This answer is streamed a few characters at a time.",
        "Each finished line is committed to your scrollback, and the line being written stays live."
    ]);
}

@test:Config {}
function testTheLineBeingWrittenIsLiveAndAFinishedLineIsNot() {
    Chat chat = new (delay = 0);
    _ = ask(chat, "hi");
    _ = chat.update(<readonly & Token>{turn: 1, text: "You as"});
    test:assertEquals(rows(chat)[0], "You as", "the unfinished line is part of the live region");
    _ = chat.update(<readonly & Token>{turn: 1, text: "ked\nNext"});
    test:assertEquals(rows(chat)[0], "Next", "the finished line left the live region");
}

@test:Config {}
function testAPieceFromAnOldTurnIsIgnored() {
    Chat chat = new (delay = 0);
    _ = ask(chat, "one");
    _ = chat.update(<readonly & Done>{turn: 1});
    _ = ask(chat, "two");
    _ = chat.update(<readonly & Token>{turn: 1, text: "late"});
    // only the prompt row is left: the late piece did not become a live line
    test:assertEquals(rows(chat).length(), 1, "a late piece of turn 1 does not show in turn 2");
}

@test:Config {}
function testASecondQuestionCanBeAskedWhenTheFirstIsDone() {
    Chat chat = new (delay = 0);
    test:assertTrue(ask(chat, "one") is termui:Command);
    // while an answer streams, Enter is ignored
    test:assertTrue(ask(chat, "two") is ());
    _ = chat.update(<readonly & Done>{turn: 1});
    test:assertTrue(chat.update(enter()) is termui:Command, "the kept text is submitted once the answer is done");
}

@test:Config {}
function testAFailedEffectEndsTheTurnAndInputWorksAgain() {
    Chat chat = new (delay = 0);
    _ = ask(chat, "one");
    termui:Command? shown = chat.update(<readonly & termui:EffectFailed>{kind: "effectFailed", reason: "no network"});
    test:assertTrue(shown is termui:Command, "the failure is reported");
    test:assertTrue(ask(chat, "two") is termui:Command, "a new question starts after the failure");
}
// endregion tests
