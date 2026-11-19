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

@test:Config {}
function testTypedTextIsShownInTheLiveRegion() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("hi!");
    check termui:run(new Echo(), terminal);
    test:assertEquals(terminal.screenText(), "> hi");
}

@test:Config {}
function testASubmittedLineIsCommittedAboveTheRegion() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("hi");
    terminal.pushKey("enter");
    terminal.pushText("!");
    check termui:run(new Echo(), terminal);
    test:assertEquals(terminal.screenLines(), ["you said: hi", ">", "", ""]);
}
