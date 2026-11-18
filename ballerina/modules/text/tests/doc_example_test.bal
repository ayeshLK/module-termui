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

// Mirrors the example in Module.md; if this test changes, update the documentation to match.
@test:Config {}
function testModuleDocExample() {
    Span[] spans = [
        {text: "error: ", style: {bold: true, fg: "red"}},
        {text: "the quick brown fox jumps over the lazy dog"}
    ];
    string[] printed = [];
    foreach Span[] line in wrap(spans, 24, 0, 7) {
        printed.push(toAnsi(line, colors = false));
    }
    printed.push(displayWidth("日本語").toString());
    // With colors off the bold attribute is still emitted, so strip it to compare with the docs.
    string[] visible = [];
    foreach string row in printed {
        visible.push(re `\u{1b}\[[0-9;]*m`.replaceAll(row, ""));
    }
    test:assertEquals(visible, ["error: the quick brown", "       fox jumps over", "       the lazy dog", "6"]);
}
