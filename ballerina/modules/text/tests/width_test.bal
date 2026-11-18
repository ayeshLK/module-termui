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
function testAsciiWidth() {
    test:assertEquals(displayWidth("hello"), 5);
    test:assertEquals(displayWidth(""), 0);
}

@test:Config {}
function testWideCharactersTakeTwoColumns() {
    test:assertEquals(displayWidth("日本語"), 6);
    test:assertEquals(displayWidth("a日b"), 4);
    test:assertEquals(displayWidth("한글"), 4);
    test:assertEquals(displayWidth("😀"), 2);
}

@test:Config {}
function testCombiningMarksTakeNoColumns() {
    test:assertEquals(displayWidth("e\u{0301}"), 1);
    test:assertEquals(displayWidth("a\u{0300}\u{0301}b"), 2);
}

@test:Config {}
function testEscapeSequencesTakeNoColumns() {
    test:assertEquals(displayWidth("\u{1b}[31mred\u{1b}[0m"), 3);
    test:assertEquals(displayWidth("\u{1b}[1;38;2;1;2;3mx\u{1b}[0m"), 1);
    test:assertEquals(displayWidth("\u{1b}]8;;https://example.com\u{07}link\u{1b}]8;;\u{07}"), 4);
    test:assertEquals(displayWidth("\u{1b}]8;;https://example.com\u{1b}\\link\u{1b}]8;;\u{1b}\\"), 4);
}

@test:Config {}
function testControlCharactersTakeNoColumns() {
    test:assertEquals(displayWidth("a\u{07}b"), 2);
}

@test:Config {}
function testZeroWidthJoinerMergesEmoji() {
    // man, joiner, woman, joiner, girl: one grapheme, two columns
    test:assertEquals(displayWidth("👨\u{200D}👩\u{200D}👧"), 2);
}

@test:Config {}
function testTruncatedEscapeSequenceDoesNotCrash() {
    test:assertEquals(displayWidth("ab\u{1b}"), 2);
    test:assertEquals(displayWidth("ab\u{1b}[31"), 2);
}
