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

import ayesha/termui.term;
import ayesha/termui.text as txt;
import ballerina/test;

function rows(string... values) returns txt:Span[][] {
    txt:Span[][] out = [];
    foreach string value in values {
        out.push([{text: value}]);
    }
    return out;
}

function inline(int width, int height, boolean reflow = true) returns [term:FakeTerminal, InlineRenderer] {
    term:FakeTerminal terminal = new (width, height);
    return [terminal, new InlineRenderer(terminal, width, height, true, reflow)];
}

// ---- 5.1 cell buffer and minimal updates -------------------------------------------------------

@test:Config {}
function testAnUnchangedFrameWritesNothing() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 5);
    check renderer.draw(rows("hello", "world"));
    int before = terminal.writes().length();
    check renderer.draw(rows("hello", "world"));
    test:assertEquals(terminal.writes().length(), before, "an identical frame must not be written");
}

@test:Config {}
function testOneChangedCellWritesOnlyThatCell() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 5);
    check renderer.draw(rows("hello", "world"));
    check renderer.draw(rows("hellO", "world"));
    string[] writes = terminal.writes();
    // up one row, to column 5, the new character, then back to column 1
    test:assertEquals(writes[writes.length() - 1], "\u{1b}[1A\u{1b}[5GO\u{1b}[1G");
    test:assertEquals(terminal.screenLines().slice(0, 2), ["hellO", "world"]);
}

@test:Config {}
function testEveryDrawIsOneWrite() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 5);
    check renderer.draw(rows("a", "b", "c"));
    check renderer.draw(rows("a", "B", "c", "d"));
    check renderer.commitProse(rows("done"));
    test:assertEquals(terminal.writes().length(), 3, "each operation is one write");
}

@test:Config {}
function testShorterTextErasesTheOldTail() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 5);
    check renderer.draw(rows("a long line of text"));
    check renderer.draw(rows("short"));
    test:assertEquals(terminal.screenLines()[0], "short");
}

@test:Config {}
function testWideCharactersAreWrittenWhole() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 5);
    check renderer.draw(rows("日本x"));
    check renderer.draw(rows("日本y"));
    test:assertEquals(terminal.screenLines()[0], "日本y");
    Buffer? frame = renderer.frame();
    if frame is Buffer {
        test:assertEquals(cellAt(frame, 0, 0).text, "日");
        test:assertEquals(cellAt(frame, 0, 1).text, "");
    } else {
        test:assertFail("there must be a frame");
    }
}

@test:Config {}
function testALongLineIsCutAtTheRightEdge() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(5, 5);
    check renderer.draw(rows("abcdefgh"));
    test:assertEquals(terminal.screenLines().slice(0, 2), ["abcde", ""]);
}

// ---- 5.2 inline live region --------------------------------------------------------------------

@test:Config {}
function testTheRegionLeavesEarlierContentAlone() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(30, 8);
    check terminal.write("$ ls\r\nfile one\r\n");
    check renderer.draw(rows("> typing", "status"));
    test:assertEquals(terminal.screenLines().slice(0, 4), ["$ ls", "file one", "> typing", "status"]);
    check renderer.draw(rows("> typing more", "status"));
    test:assertEquals(terminal.screenLines().slice(0, 4), ["$ ls", "file one", "> typing more", "status"]);
}

@test:Config {}
function testGrowingAndShrinkingLeavesNoRowsBehind() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(30, 10);
    check terminal.write("above\r\n");
    check renderer.draw(rows("one", "two"));
    check renderer.draw(rows("one", "two", "three", "four"));
    test:assertEquals(terminal.screenLines().slice(0, 6), ["above", "one", "two", "three", "four", ""]);
    check renderer.draw(rows("only"));
    test:assertEquals(terminal.screenLines().slice(0, 4), ["above", "only", "", ""]);
    check renderer.draw(rows("a", "b", "c"));
    test:assertEquals(terminal.screenLines().slice(0, 5), ["above", "a", "b", "c", ""]);
}

@test:Config {}
function testAnEmptyRegionClearsEverythingItDrew() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(30, 10);
    check terminal.write("above\r\n");
    check renderer.draw(rows("one", "two"));
    check renderer.draw([]);
    test:assertEquals(terminal.screenText(), "above");
    check renderer.draw(rows("back"));
    test:assertEquals(terminal.screenLines().slice(0, 3), ["above", "back", ""]);
}

@test:Config {}
function testARegionAtTheBottomOfTheScreenScrollsAndStaysCorrect() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 4);
    check terminal.write("h1\r\nh2\r\nh3\r\n");
    check renderer.draw(rows("r1", "r2", "r3"));
    test:assertEquals(terminal.screenLines(), ["h3", "r1", "r2", "r3"]);
    test:assertEquals(terminal.scrollbackLines(), ["h1", "h2"]);
    check renderer.draw(rows("r1", "R2", "r3"));
    test:assertEquals(terminal.screenLines(), ["h3", "r1", "R2", "r3"]);
}

@test:Config {}
function testARegionTallerThanTheTerminalKeepsTheLastRows() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 3);
    check renderer.draw(rows("a", "b", "c", "d", "e"));
    test:assertEquals(terminal.screenLines(), ["c", "d", "e"]);
}

// ---- 5.3 commit above the live region -----------------------------------------------------------

@test:Config {}
function testCommittedOutputAppearsAboveTheRegion() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(30, 10);
    check renderer.draw(rows("> input", "status"));
    check renderer.commitProse(rows("first answer", "second answer"));
    test:assertEquals(terminal.screenLines().slice(0, 5), ["first answer", "second answer", "> input", "status", ""]);
    check renderer.draw(rows("> input!", "status"));
    test:assertEquals(terminal.screenLines().slice(0, 4), ["first answer", "second answer", "> input!", "status"]);
}

@test:Config {}
function testCommittedOutputIsNeverRedrawn() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(30, 10);
    check renderer.draw(rows("> input"));
    check renderer.commitProse(rows("finished line"));
    int before = terminal.writes().length();
    check renderer.draw(rows("> input", "more"));
    check renderer.draw(rows("> changed", "more"));
    foreach string write in terminal.writes().slice(before) {
        test:assertFalse(write.includes("finished"), "committed text must not be written again");
    }
}

@test:Config {}
function testAParagraphIsCommittedAsOneLogicalLine() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(10, 10);
    check renderer.commitProse(rows("the quick brown fox jumps over"));
    string[] writes = terminal.writes();
    test:assertEquals(writes[0], "the quick brown fox jumps over\r\n", "no line break may be added inside the paragraph");
    test:assertEquals(terminal.screenLines().slice(0, 4), ["the quick ", "brown fox ", "jumps over", ""].map(s => s.trim()));
}

@test:Config {}
function testNewlinesInAParagraphBecomeCarriageReturnLineFeed() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 10);
    check renderer.commitProse(rows("a\nb"));
    test:assertEquals(terminal.screenLines().slice(0, 2), ["a", "b"]);
}

@test:Config {}
function testABlockIsWrappedToTheWidthWhenCommitted() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(10, 10);
    check renderer.commitBlock(rows("| a | b | c | d |", "short"));
    string[] writes = terminal.writes();
    test:assertTrue(writes[0].includes("\r\n"));
    foreach string line in terminal.screenLines() {
        test:assertTrue(txt:displayWidth(line) <= 10);
    }
    test:assertEquals(terminal.screenLines()[0], "| a | b |");
}

// ---- 5.4 resize --------------------------------------------------------------------------------

function resizeScenario(boolean reflow, int newWidth) returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 12, reflow);
    check renderer.commitProse(rows("history one", "history two"));
    check renderer.draw(rows("abcdefghijklmnopqrst", "second row of region", "third"));
    terminal.resize(newWidth, 12, reflow);
    check renderer.resize(newWidth, 12);
    check renderer.draw(rows("NEW1", "NEW2"));
    string text = terminal.screenText();
    test:assertTrue(text.endsWith("NEW1\nNEW2"), "the new region must be the last rows: " + text);
    test:assertFalse(text.includes("abcd"), "no stale row of the old region may remain: " + text);
    test:assertFalse(text.includes("second"), "no stale row of the old region may remain: " + text);
    test:assertFalse(text.includes("third"), "no stale row of the old region may remain: " + text);
}

@test:Config {}
function testNarrowingAReflowingTerminalLeavesNoStaleRows() returns error? {
    check resizeScenario(true, 8);
}

@test:Config {}
function testWideningAReflowingTerminalLeavesNoStaleRows() returns error? {
    check resizeScenario(true, 40);
}

@test:Config {}
function testNarrowingATerminalThatCutsTextLeavesNoStaleRows() returns error? {
    check resizeScenario(false, 8);
}

@test:Config {}
function testWideningATerminalThatCutsTextLeavesNoStaleRows() returns error? {
    check resizeScenario(false, 40);
}

@test:Config {}
function testResizeDoesNotTouchCommittedHistory() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 12);
    check renderer.commitProse(rows("keep me"));
    check renderer.draw(rows("region"));
    terminal.resize(40, 12);
    check renderer.resize(40, 12);
    check renderer.draw(rows("region"));
    test:assertEquals(terminal.screenLines().slice(0, 2), ["keep me", "region"]);
}

// ---- 5.5 full screen ---------------------------------------------------------------------------

@test:Config {}
function testFullScreenRestoresThePreviousContents() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 6);
    check renderer.commitProse(rows("history"));
    check renderer.draw(rows("> region"));
    string before = terminal.screenText();
    check renderer.enterFullScreen();
    check renderer.draw(rows("FULL", "SCREEN"));
    test:assertEquals(terminal.screenLines().slice(0, 3), ["FULL", "SCREEN", ""]);
    check renderer.draw(rows("FULL", "SCREEN!", "three"));
    test:assertEquals(terminal.screenLines().slice(0, 3), ["FULL", "SCREEN!", "three"]);
    check renderer.leaveFullScreen();
    test:assertEquals(terminal.screenText(), before);
    // the inline region works again where it was
    check renderer.draw(rows("> region 2"));
    test:assertEquals(terminal.screenLines().slice(0, 2), ["history", "> region 2"]);
}

@test:Config {}
function testCommittingIsNotAvailableInFullScreen() returns error? {
    [term:FakeTerminal, InlineRenderer] [_, renderer] = inline(20, 6);
    check renderer.enterFullScreen();
    test:assertTrue(renderer.commitProse(rows("x")) is error);
}

@test:Config {}
function testClosingMovesToAFreshLine() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 6);
    check renderer.draw(rows("a", "b"));
    check renderer.close();
    check terminal.write("$ ");
    test:assertEquals(terminal.screenLines().slice(0, 4), ["a", "b", "$", ""]);
}

// ---- 5.6 plain renderer and frame inspection ------------------------------------------------------

@test:Config {}
function testPlainOutputHasNoEscapeSequences() returns error? {
    term:FakeTerminal terminal = new (40, 10);
    PlainRenderer renderer = new (terminal, 40);
    check renderer.commitProse([[{text: "bold", style: {bold: true, fg: "red"}}, {text: " words"}]]);
    check renderer.commitBlock(rows("| table |"));
    check renderer.close();
    string all = string:'join("", ...terminal.writes());
    test:assertEquals(all, "bold words\n| table |\n");
    test:assertFalse(all.includes("\u{1b}"));
    test:assertFalse(all.includes("\r"));
}

@test:Config {}
function testASpinnerIsNotRepeatedInPlainOutput() returns error? {
    term:FakeTerminal terminal = new (40, 10);
    PlainRenderer renderer = new (terminal, 40);
    foreach string frame in ["|", "/", "-", "\\", "|", "/"] {
        check renderer.draw(rows("working " + frame));
    }
    test:assertEquals(terminal.writes().length(), 0, "drawing alone writes nothing");
    check renderer.commitProse(rows("step finished"));
    check renderer.close();
    string all = string:'join("", ...terminal.writes());
    test:assertEquals(all, "step finished\nworking /\n", "only the final state of the live region is written");
}

@test:Config {}
function testPlainRendererStripsEscapeSequencesFromText() returns error? {
    term:FakeTerminal terminal = new (40, 10);
    PlainRenderer renderer = new (terminal, 40);
    check renderer.commitProse(rows("\u{1b}[31mred\u{1b}[0m text"));
    test:assertEquals(terminal.writes(), ["red text\n"]);
}

@test:Config {}
function testAFrameCanBeCheckedForTextAndStyle() returns error? {
    [term:FakeTerminal, InlineRenderer] [_, renderer] = inline(20, 5);
    check renderer.draw([
        [{text: "err", style: {bold: true, fg: "red"}}, {text: ": plain"}],
        [{text: "ok", style: {bg: {r: 1, g: 2, b: 3}}}]
    ]);
    Buffer? frame = renderer.frame();
    if frame is Buffer {
        test:assertEquals(bufferLines(frame), ["err: plain", "ok"]);
        Cell first = cellAt(frame, 0, 0);
        test:assertEquals(first.text, "e");
        test:assertTrue(first.style.bold);
        test:assertEquals(first.style?.fg, "red");
        test:assertFalse(cellAt(frame, 0, 5).style.bold);
        test:assertEquals(cellAt(frame, 1, 0).style?.bg, <txt:RgbColor>{r: 1, g: 2, b: 3});
    } else {
        test:assertFail("there must be a frame");
    }
}

@test:Config {}
function testStylesAreWrittenAsSequencesAndOnlyWhereTheyChange() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 5);
    check renderer.draw([[{text: "a", style: {bold: true}}, {text: "bc"}]]);
    test:assertEquals(terminal.writes()[0], "\u{1b}[1G\u{1b}[1ma\u{1b}[0mbc\u{1b}[1G");
}

@test:Config {}
function testColorsCanBeTurnedOff() returns error? {
    term:FakeTerminal terminal = new (20, 5);
    InlineRenderer renderer = new (terminal, 20, 5, colors = false);
    check renderer.draw([[{text: "x", style: {fg: "red"}}]]);
    test:assertEquals(terminal.writes()[0], "\u{1b}[1Gx\u{1b}[1G");
}
