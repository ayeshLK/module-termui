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

function addItem(term:FakeTerminal terminal, string text) {
    terminal.pushText("a");
    terminal.pushText(text);
    terminal.pushKey("enter");
}

// region tests
@test:Config {}
function testAnItemCanBeAdded() returns error? {
    TodoList list = new;
    _ = check play(list, t => addItem(t, "buy milk"));
    test:assertEquals(list.items, [{text: "buy milk", done: false}]);
}

@test:Config {}
function testAnEmptyItemIsNotAdded() returns error? {
    TodoList list = new;
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("a");
        t.pushText("   ");
        t.pushKey("enter");
    });
    test:assertEquals(list.items.length(), 0);
}

@test:Config {}
function testEscapeGivesUpAnAdd() returns error? {
    TodoList list = new;
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("a");
        t.pushText("never");
        t.pushKey("escape");
    });
    test:assertEquals(list.items.length(), 0);
    test:assertFalse(list.adding);
}

@test:Config {}
function testWhileAddingKeysGoToTheEditorNotTheList() returns error? {
    TodoList list = new ([{text: "one"}]);
    _ = check play(list, function(term:FakeTerminal t) {
        t.pushText("a");
        t.pushText("d");
        t.pushKey("escape");
    });
    test:assertEquals(list.items, [{text: "one", done: false}]);
}
// endregion tests
