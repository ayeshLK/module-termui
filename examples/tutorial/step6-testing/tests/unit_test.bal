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

// Layer 1: call update and view directly. Fast and exact, and the way to test what happens between two
// messages of an answer, which a full run cannot pause on.

import ayesha/termui;
import ballerina/test;

// region unit-tests
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
    _ = chat.update(<readonly & Done>{turn: 1, interrupted: false});
    _ = ask(chat, "two");
    _ = chat.update(<readonly & Token>{turn: 1, text: "late"});
    test:assertFalse(rows(chat).toString().includes("late"), "a late piece of turn 1 does not show in turn 2");
}

@test:Config {}
function testTicksDoNotChangeTheViewWhileIdle() {
    Chat chat = new (delay = 0);
    string[] before = rows(chat);
    foreach int _ in 0 ..< 7 {
        _ = chat.update(<readonly & Tick>{kind: "tick"});
    }
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
// endregion unit-tests
