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

// Layers 2 and 3: run the whole program on a fake terminal, scripting the keys, and read what a person
// would see. The gated terminal answers the question when it appears.

import ayesha/termui;
import ayesha/termui.term;
import ballerina/test;

// region session-tests
@test:Config {}
function testASessionWithAnApprovedToolHasTheWholeTranscript() returns error? {
    term:FakeTerminal terminal = new (100, 14);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    check termui:run(new Chat(delay = 0), new GatedTerminal(terminal, "Allow Bash", "y"));
    test:assertEquals(terminal.screenLines().slice(0, 7), [
        "❯ hi",
        "You asked: hi",
        "This answer is streamed a few characters at a time.",
        "Each finished line is committed to your scrollback, and the line being written stays live.",
        "● Bash(bal test)",
        "  ⎿  12 passed, 0 failed",
        ""
    ]);
}

@test:Config {}
function testADeniedToolIsReportedAndDoesNotRun() returns error? {
    term:FakeTerminal terminal = new (100, 14);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    check termui:run(new Chat(delay = 0), new GatedTerminal(terminal, "Allow Bash", "n"));
    string screen = terminal.screenText();
    test:assertTrue(screen.includes("denied by user"), screen);
    test:assertFalse(screen.includes("12 passed"), "the tool did not run");
}

@test:Config {}
function testEscStopsTheAnswerBeforeAnyToolIsAsked() returns error? {
    term:FakeTerminal terminal = new (100, 8);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    terminal.pushKey("escape"); // handled while the model is still "thinking"
    check termui:run(new Chat(delay = 0.01), terminal, {interactive: false});
    test:assertEquals(terminal.screenLines().slice(0, 2), ["❯ hi", "⏹ Interrupted"]);
}
// endregion session-tests
