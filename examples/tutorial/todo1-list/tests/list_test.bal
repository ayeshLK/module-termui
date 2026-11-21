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

import ayesha/termui;
import ayesha/termui.term;
import ballerina/test;

// Runs a list against a fake terminal that is 40 columns by 8 rows, after the keys have been typed.
function play(TodoList list, function (term:FakeTerminal) keys) returns string[]|error {
    term:FakeTerminal terminal = new (40, 8);
    keys(terminal);
    check termui:run(list, terminal);
    return terminal.screenLines();
}

// region tests
@test:Config {}
function testTheSelectedItemIsMarked() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    string[] lines = check play(list, function(term:FakeTerminal t) {
        t.pushKey("down");
    });
    test:assertEquals(lines.slice(0, 2), ["  one", "> two"]);
}

@test:Config {}
function testTheSelectionStaysInRange() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushKey("up");
        t.pushKey("down");
        t.pushKey("down");
        t.pushKey("down");
    });
    test:assertEquals(list.selected, 1);
}

@test:Config {}
function testQBeforeTheEndOfInputQuitsTheProgram() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("q");
        t.pushKey("down");
    });
    test:assertEquals(list.selected, 0);
}
// endregion tests
