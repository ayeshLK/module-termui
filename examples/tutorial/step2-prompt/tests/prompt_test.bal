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

// region tests
@test:Config {}
function testTypedTextIsShownInThePrompt() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("hi");
    terminal.pushEvent(ctrlC());
    check termui:run(new Prompt(), terminal);
    test:assertEquals(terminal.screenLines()[0], "❯ hi");
}

@test:Config {}
function testASubmittedLineIsCommittedAboveTheEmptyPrompt() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("hello");
    terminal.pushKey("enter");
    terminal.pushEvent(ctrlC());
    check termui:run(new Prompt(), terminal);
    test:assertEquals(terminal.screenLines().slice(0, 2), ["❯ hello", "❯"]);
}

@test:Config {}
function testUpRecallsTheLastSubmission() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("one");
    terminal.pushKey("enter");
    terminal.pushKey("up");
    terminal.pushEvent(ctrlC());
    check termui:run(new Prompt(), terminal);
    test:assertEquals(terminal.screenLines().slice(0, 2), ["❯ one", "❯ one"]);
}

@test:Config {}
function testTheProgramEndsWhenItsInputEnds() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("x");
    // no quit key: the fake terminal reports the end of input, and the program quits
    check termui:run(new Prompt(), terminal);
    test:assertEquals(terminal.screenLines()[0], "❯ x");
}
// endregion tests
