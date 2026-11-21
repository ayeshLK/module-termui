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
function testSpaceTogglesTheSelectedItem() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushKey("down");
        t.pushText(" ");
    });
    test:assertEquals(list.items, [{text: "one", done: false}, {text: "two", done: true}]);
}

@test:Config {}
function testADoneItemIsShownChecked() returns error? {
    TodoList list = new ([{text: "one", done: true}, {text: "two"}]);
    string[] lines = check play(list, function(term:FakeTerminal t) {});
    test:assertEquals(lines.slice(0, 2), ["> [x] one", "  [ ] two"]);
}

@test:Config {}
function testDeletingTheLastItemMovesTheSelectionUp() returns error? {
    TodoList list = new ([{text: "one"}, {text: "two"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushKey("down");
        t.pushText("d");
    });
    test:assertEquals(list.items, [{text: "one", done: false}]);
    test:assertEquals(list.selected, 0);
}

@test:Config {}
function testDeletingTheOnlyItemLeavesAnEmptyList() returns error? {
    TodoList list = new ([{text: "one"}]);
    string[] lines = check play(list, function(term:FakeTerminal t) {
        t.pushText("d");
        t.pushText("d");
        t.pushText(" ");
    });
    test:assertEquals(list.items.length(), 0);
    test:assertEquals(list.selected, 0);
    test:assertEquals(lines[0], "Nothing to do.");
}
// endregion tests
