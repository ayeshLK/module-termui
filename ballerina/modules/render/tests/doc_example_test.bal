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

import ayesha/termui.term;
import ballerina/test;

// Mirrors the example in Module.md; if this test changes, update the documentation to match.
@test:Config {}
function testModuleDocExample() returns error? {
    term:FakeTerminal terminal = new (30, 8);
    InlineRenderer renderer = new (terminal, 30, 8);
    check renderer.commitProse([[{text: "Hello!"}]]);
    check renderer.draw([[{text: "> typing"}]]);
    test:assertEquals(terminal.screenText(), "Hello!\n> typing");
}
