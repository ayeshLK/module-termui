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

function widest(string[] lines) returns int {
    int most = 0;
    foreach string line in lines {
        most = int:max(most, displayWidth(line));
    }
    return most;
}

@test:Config {}
function testWrapsAtSpaces() {
    test:assertEquals(wrapText("The quick brown fox jumps over the lazy dog", 20),
            ["The quick brown fox", "jumps over the lazy", "dog"]);
}

@test:Config {}
function testNoLineExceedsTheWidth() {
    string text = "Pack my box with five dozen liquor jugs and keep every single line within the limit";
    foreach int width in [8, 12, 20, 33] {
        test:assertTrue(widest(wrapText(text, width)) <= width, string `width ${width} exceeded`);
    }
}

@test:Config {}
function testExactFitStaysOnOneLine() {
    test:assertEquals(wrapText("aaaa bbbb", 9), ["aaaa bbbb"]);
    test:assertEquals(wrapText("aaaa bbbb", 8), ["aaaa", "bbbb"]);
}

@test:Config {}
function testOverlongWordIsSplitAtTheWidth() {
    test:assertEquals(wrapText("abcdefghijkl", 5), ["abcde", "fghij", "kl"]);
    test:assertEquals(wrapText("ab abcdefghijkl", 5), ["ab", "abcde", "fghij", "kl"]);
}

@test:Config {}
function testSpacesAtAWrapPointAreDropped() {
    test:assertEquals(wrapText("aaaa  bbbb", 4), ["aaaa", "bbbb"]);
}

@test:Config {}
function testLeadingSpacesAreKept() {
    test:assertEquals(wrapText("  hi there", 20), ["  hi there"]);
}

@test:Config {}
function testNewlinesForceBreaks() {
    test:assertEquals(wrapText("a\nb", 10), ["a", "b"]);
    test:assertEquals(wrapText("a\n\nb", 10), ["a", "", "b"]);
}

@test:Config {}
function testEmptyTextGivesOneEmptyLine() {
    test:assertEquals(wrapText("", 10), [""]);
}

@test:Config {}
function testHangingIndent() {
    string[] lines = wrapText("- one two three four five", 12, 0, 2);
    test:assertEquals(lines, ["- one two", "  three four", "  five"]);
    test:assertTrue(widest(lines) <= 12);
}

@test:Config {}
function testWideCharactersAreMeasuredByColumns() {
    test:assertEquals(wrapText("日本語日本語", 5), ["日本", "語日", "本語"]);
}

@test:Config {}
function testCombiningMarksStayWithTheirBase() {
    test:assertEquals(wrapText("e\u{0301}e\u{0301}", 1), ["e\u{0301}", "e\u{0301}"]);
}

@test:Config {}
function testEscapeSequencesDoNotCountTowardsTheWidth() {
    string[] lines = wrapText("\u{1b}[31mred\u{1b}[0m word", 4);
    test:assertEquals(lines, ["\u{1b}[31mred\u{1b}[0m", "word"]);
    test:assertTrue(widest(lines) <= 4);
}

@test:Config {}
function testTinyWidthsTerminate() {
    test:assertEquals(wrapText("abc", 1), ["a", "b", "c"]);
    test:assertEquals(wrapText("日本", 1), ["日", "本"]);
    test:assertEquals(wrapText("abc", 0), ["a", "b", "c"]);
}

@test:Config {}
function testStyleContinuesAcrossABreak() {
    Span[] spans = [{text: "aa "}, {text: "boldwordlong", style: {bold: true}}];
    Span[][] lines = wrap(spans, 8);
    test:assertEquals(lines.length(), 3);
    test:assertEquals(plainText(lines[0]), "aa");
    test:assertEquals(plainText(lines[1]), "boldword");
    test:assertEquals(plainText(lines[2]), "long");
    test:assertTrue(lines[1][0].style.bold);
    test:assertTrue(lines[2][0].style.bold);
    test:assertFalse(lines[0][0].style.bold);
}

@test:Config {}
function testNeighbouringSpansWithOneStyleAreMerged() {
    Span[][] lines = wrap([{text: "ab", style: {bold: true}}, {text: "cd", style: {bold: true}}, {text: "ef"}], 10);
    test:assertEquals(lines.length(), 1);
    test:assertEquals(lines[0].length(), 2);
    test:assertEquals(lines[0][0].text, "abcd");
    test:assertEquals(lines[0][1].text, "ef");
}

@test:Config {}
function testWordsAreNotBrokenAtSpanBoundaries() {
    Span[][] lines = wrap([{text: "foo ", style: {bold: true}}, {text: "bar baz"}], 7);
    test:assertEquals(lines.length(), 2);
    test:assertEquals(plainText(lines[0]), "foo bar");
    test:assertEquals(plainText(lines[1]), "baz");
}
