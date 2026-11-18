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

@test:Config {}
function testMixedStylesInALine() {
    string out = toAnsi([{text: "bold", style: {bold: true}}, {text: " plain"}]);
    test:assertEquals(out, "\u{1b}[1mbold\u{1b}[0m plain");
}

@test:Config {}
function testNamedIndexedAndRgbColors() {
    test:assertEquals(sgr({fg: "red"}), "\u{1b}[31m");
    test:assertEquals(sgr({bg: "brightBlue"}), "\u{1b}[104m");
    test:assertEquals(sgr({fg: {index: 208}}), "\u{1b}[38;5;208m");
    test:assertEquals(sgr({bg: {r: 1, g: 2, b: 3}}), "\u{1b}[48;2;1;2;3m");
}

@test:Config {}
function testAttributesComeBeforeColors() {
    test:assertEquals(sgr({bold: true, underline: true, fg: "green", bg: "black"}), "\u{1b}[1;4;32;40m");
    test:assertEquals(sgr({dim: true, italic: true, reverse: true}), "\u{1b}[2;3;7m");
}

@test:Config {}
function testDefaultStyleHasNoSequence() {
    test:assertEquals(sgr({}), "");
    test:assertEquals(toAnsi([{text: "plain"}]), "plain");
}

@test:Config {}
function testColorsDisabledKeepsCharactersAndAttributes() {
    Span[] spans = [{text: "red", style: {fg: "red"}}, {text: " bold", style: {bold: true, fg: "blue"}}];
    test:assertEquals(toAnsi(spans, false), "red\u{1b}[1m bold\u{1b}[0m");
    test:assertEquals(plainText(spans), "red bold");
}

@test:Config {}
function testEmptySpansAreSkipped() {
    test:assertEquals(toAnsi([{text: "", style: {bold: true}}, {text: "x"}]), "x");
}
