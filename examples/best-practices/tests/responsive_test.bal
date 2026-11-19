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
function testWorkInUpdateMakesTheInterfaceWait() returns error? {
    term:FakeTerminal terminal = new (30, 3);
    Job job = new (true);
    check termui:run(job, terminal);
    decimal gap = job.longestGap();
    test:assertTrue(gap >= 0.45d, string `expected a silence of about 0.5 s, got ${gap.toString()} s`);
}

@test:Config {}
function testWorkInAnEffectKeepsTheInterfaceResponsive() returns error? {
    term:FakeTerminal terminal = new (30, 3);
    Job job = new (false);
    check termui:run(job, terminal);
    decimal gap = job.longestGap();
    test:assertTrue(gap < 0.3d, string `ticks were handled at least every 0.3 s, but the longest gap was ${gap.toString()} s`);
    test:assertEquals(job.status, "done");
}
