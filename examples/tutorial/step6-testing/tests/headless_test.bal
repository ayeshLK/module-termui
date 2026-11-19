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

// Layer 4: the headless run. An Interface built from an environment where nothing is a terminal chooses
// plain output and no questions, exactly as it does for a script or CI. The terminal is a fake one, so the
// test can read everything that was written.

import ayesha/termui;
import ayesha/termui.term;
import ballerina/test;

// region headless-tests
function headlessEnvironment() returns term:Environment {
    return {
        stdinIsTerminal: false,
        stdoutIsTerminal: false,
        stderrIsTerminal: false,
        dumbTerminal: false,
        noColor: false,
        colorEnabled: false,
        width: 100,
        height: 14
    };
}

@test:Config {}
function testAHeadlessRunWritesPlainTextAndDeniesTheTool() returns error? {
    term:FakeTerminal terminal = new (100, 14);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    termui:Interface ui = new (headlessEnvironment(), terminal = terminal);
    test:assertEquals(ui.mode, "headless");
    test:assertFalse(ui.interactive, "nobody can answer a question");

    check ui.run(new Chat(delay = 0));

    string output = string:'join("", ...terminal.writes());
    test:assertFalse(output.includes("\u{1B}"), "no escape sequences in plain output");
    test:assertFalse(output.includes("\r"), "no carriage returns in plain output");
    test:assertTrue(output.includes("You asked: hi"), "the answer is in the output");
    test:assertTrue(output.includes("denied by user"), "the question took its default");
    test:assertFalse(output.includes("12 passed"), "and nothing ran unapproved");
}
// endregion headless-tests
