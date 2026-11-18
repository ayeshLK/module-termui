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

import ballerina/test;

// What every Terminal implementation must do, whether or not it can also deliver input without blocking.
function exerciseTerminal(Terminal terminal) returns error? {
    check terminal.acquire();
    test:assertTrue(terminal.acquire() is error, "a second acquire must fail");
    Size size = check terminal.size();
    test:assertTrue(size.width > 0 && size.height > 0, "the size must be positive");
    check terminal.write("x");
    check terminal.release();
    check terminal.release(); // releasing twice is safe
    check terminal.acquire(); // and the terminal can be acquired again
    check terminal.release();
}

@test:Config {}
function testFakeTerminalConformsToTheInterface() returns error? {
    FakeTerminal fake = new (40, 10);
    check exerciseTerminal(fake);
}

@test:Config {}
function testEventTypesDistinguishThemselvesByKind() {
    InputEvent[] events = [{key: "a"}, {text: "pasted"}, {width: 10, height: 5}];
    string[] kinds = [];
    foreach InputEvent event in events {
        kinds.push(event.kind);
    }
    test:assertEquals(kinds, ["key", "paste", "resize"]);
}
