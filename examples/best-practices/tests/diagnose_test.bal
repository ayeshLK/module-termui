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


import ayesha/termui.term;
import ballerina/test;

@test:Config {}
function testACiJobIsHeadlessWithoutColor() {
    term:Environment environment = term:environmentFrom({}, false, false, false);
    test:assertEquals(describeEnvironment(environment),
        "mode: headless; stdin is a terminal: false; stdout is a terminal: false; " +
        "stderr is a terminal: false; color: false; fallback size: 80x24");
}

@test:Config {}
function testATerminalIsInteractiveWithColor() {
    term:Environment environment = term:environmentFrom({"COLUMNS": "100", "LINES": "30"}, true, true, true);
    test:assertEquals(describeEnvironment(environment),
        "mode: interactive; stdin is a terminal: true; stdout is a terminal: true; " +
        "stderr is a terminal: true; color: true; fallback size: 100x30");
}

@test:Config {}
function testRedirectedOutputIsPipedOutput() {
    term:Environment environment = term:environmentFrom({}, true, false, true);
    test:assertTrue(describeEnvironment(environment).startsWith("mode: pipedOutput;"));
}

@test:Config {}
function testNoColorTurnsColorOffOnATerminal() {
    term:Environment environment = term:environmentFrom({"NO_COLOR": "1"}, true, true, true);
    test:assertTrue(describeEnvironment(environment).includes("color: false"));
    test:assertTrue(describeEnvironment(environment).startsWith("mode: interactive;"));
}
