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
import ayesha/termui.text;
import ballerina/test;

// ---- helpers ------------------------------------------------------------------------------------

function key(string:Char|term:NamedKey key, boolean ctrl = false, boolean alt = false) returns term:KeyEvent {
    return {kind: "key", key, ctrl, alt};
}

// Types printable characters one by one.
function typed(LineEditor editor, string value) {
    foreach string:Char char in value {
        EditResult _ = editor.handleEvent(key(char));
    }
}

function press(LineEditor editor, string:Char|term:NamedKey pressed, boolean ctrl = false, boolean alt = false, int times = 1) returns EditResult {
    EditResult result = "ignored";
    foreach int _ in 0 ..< times {
        result = editor.handleEvent(key(pressed, ctrl, alt));
    }
    return result;
}

function paste(LineEditor editor, string value) returns EditResult {
    term:PasteEvent event = {kind: "paste", text: value};
    return editor.handleEvent(event);
}

function plain(text:Span[][] lines) returns string[] {
    string[] rows = [];
    foreach text:Span[] line in lines {
        string row = "";
        foreach text:Span span in line {
            row += span.text;
        }
        rows.push(row);
    }
    return rows;
}

// The text drawn in reverse video, one entry per row ("" for a row without the cursor).
function reversed(text:Span[][] lines) returns string[] {
    string[] marks = [];
    foreach text:Span[] line in lines {
        string mark = "";
        foreach text:Span span in line {
            if span.style.reverse {
                mark += span.text;
            }
        }
        marks.push(mark);
    }
    return marks;
}

// ---- 1.1 editing ----------------------------------------------------------------------------------

@test:Config {}
function testTypingInsertsAtTheCursor() {
    LineEditor editor = new;
    typed(editor, "hi");
    test:assertEquals(editor.text(), "hi");
    test:assertEquals(editor.cursor(), 2);
    test:assertEquals(press(editor, "left"), "edited");
    typed(editor, "!");
    test:assertEquals(editor.text(), "h!i");
    test:assertEquals(editor.cursor(), 2);
}

@test:Config {}
function testBackspaceAndDelete() {
    LineEditor editor = new;
    typed(editor, "ab");
    EditResult _ = press(editor, "left");
    EditResult _ = press(editor, "backspace");
    test:assertEquals(editor.text(), "b");
    EditResult _ = press(editor, "delete");
    test:assertEquals(editor.text(), "");
    // at the edges they change nothing
    EditResult _ = press(editor, "backspace");
    EditResult _ = press(editor, "delete");
    test:assertEquals(editor.text(), "");
    test:assertEquals(editor.cursor(), 0);
}

@test:Config {}
function testKeysTheEditorDoesNotUseAreIgnored() {
    LineEditor editor = new;
    typed(editor, "abc");
    test:assertEquals(press(editor, "c", ctrl = true), "ignored");
    test:assertEquals(press(editor, "escape"), "ignored");
    test:assertEquals(press(editor, "tab"), "ignored");
    test:assertEquals(press(editor, "x", alt = true), "ignored");
    test:assertEquals(press(editor, "f5"), "ignored");
    test:assertEquals(editor.text(), "abc");
    test:assertEquals(editor.cursor(), 3);
}

@test:Config {}
function testWideAndCombiningCharactersAreOneCharacterEach() {
    LineEditor editor = new;
    typed(editor, "日e");
    typed(editor, "\u{301}");
    test:assertEquals(editor.text(), "日e\u{301}");
    test:assertEquals(editor.cursor(), 2, "the accent belongs to the e");
    EditResult _ = press(editor, "backspace");
    test:assertEquals(editor.text(), "日", "backspace removes the letter with its accent");
}

// ---- 1.2 movement ---------------------------------------------------------------------------------

@test:Config {}
function testWordMovement() {
    LineEditor editor = new;
    typed(editor, "one two");
    EditResult _ = press(editor, "b", alt = true);
    test:assertEquals(editor.cursor(), 4);
    EditResult _ = press(editor, "left", ctrl = true);
    test:assertEquals(editor.cursor(), 0);
    EditResult _ = press(editor, "f", alt = true);
    test:assertEquals(editor.cursor(), 3);
    EditResult _ = press(editor, "right", alt = true);
    test:assertEquals(editor.cursor(), 7);
    EditResult _ = press(editor, "right", ctrl = true);
    test:assertEquals(editor.cursor(), 7, "at the end nothing moves");
}

@test:Config {}
function testLineStartAndEndAndCharacterKeys() {
    LineEditor editor = new;
    typed(editor, "abc");
    EditResult _ = press(editor, "a", ctrl = true);
    test:assertEquals(editor.cursor(), 0);
    EditResult _ = press(editor, "f", ctrl = true);
    test:assertEquals(editor.cursor(), 1);
    EditResult _ = press(editor, "e", ctrl = true);
    test:assertEquals(editor.cursor(), 3);
    EditResult _ = press(editor, "b", ctrl = true);
    test:assertEquals(editor.cursor(), 2);
    EditResult _ = press(editor, "home");
    test:assertEquals(editor.cursor(), 0);
    EditResult _ = press(editor, "end");
    test:assertEquals(editor.cursor(), 3);
}

@test:Config {}
function testTheCursorNeverStopsInsideACharacterWithItsAccent() {
    LineEditor editor = new;
    typed(editor, "e\u{301}");
    test:assertEquals(editor.cursor(), 1);
    EditResult _ = press(editor, "left");
    test:assertEquals(editor.cursor(), 0, "one step moves before the letter");
    EditResult _ = press(editor, "left");
    test:assertEquals(editor.cursor(), 0, "the edge");
}

@test:Config {}
function testHomeAndEndWorkOnTheCurrentLine() {
    LineEditor editor = new;
    typed(editor, "ab");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "cd");
    EditResult _ = press(editor, "home");
    test:assertEquals(editor.cursor(), 3, "start of the second line");
    EditResult _ = press(editor, "end");
    test:assertEquals(editor.cursor(), 5);
    EditResult _ = press(editor, "a", ctrl = true);
    EditResult _ = press(editor, "left");
    test:assertEquals(editor.cursor(), 2, "left from the start of line two lands on the line break");
    EditResult _ = press(editor, "e", ctrl = true);
    test:assertEquals(editor.cursor(), 2, "the end of line one");
}

// ---- 1.3 deleting by word and line ----------------------------------------------------------------

@test:Config {}
function testDeleteTheWordBeforeTheCursor() {
    LineEditor editor = new;
    typed(editor, "one two");
    EditResult _ = press(editor, "w", ctrl = true);
    test:assertEquals(editor.text(), "one ");
    EditResult _ = press(editor, "w", ctrl = true);
    test:assertEquals(editor.text(), "");
    EditResult _ = press(editor, "w", ctrl = true);
    test:assertEquals(editor.text(), "", "nothing to delete");
}

@test:Config {}
function testDeleteTheWordAfterTheCursor() {
    LineEditor editor = new;
    typed(editor, "one two");
    EditResult _ = press(editor, "a", ctrl = true);
    EditResult _ = press(editor, "d", alt = true);
    test:assertEquals(editor.text(), " two");
    test:assertEquals(editor.cursor(), 0);
}

@test:Config {}
function testDeleteToTheEndAndToTheStartOfTheLine() {
    LineEditor editor = new;
    typed(editor, "one two");
    EditResult _ = press(editor, "b", alt = true);
    EditResult _ = press(editor, "left");
    test:assertEquals(editor.cursor(), 3);
    EditResult _ = press(editor, "k", ctrl = true);
    test:assertEquals(editor.text(), "one");
    typed(editor, " x");
    EditResult _ = press(editor, "left", times = 2);
    EditResult _ = press(editor, "u", ctrl = true);
    test:assertEquals(editor.text(), " x");
    test:assertEquals(editor.cursor(), 0);
}

@test:Config {}
function testKillKeysStayOnTheirLine() {
    LineEditor editor = new;
    typed(editor, "ab");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "cd");
    EditResult _ = press(editor, "left");
    EditResult _ = press(editor, "u", ctrl = true);
    test:assertEquals(editor.text(), "ab\nd");
    EditResult _ = press(editor, "k", ctrl = true);
    test:assertEquals(editor.text(), "ab\n");
}

@test:Config {}
function testCtrlDDeletesTheCharacterAfterTheCursorOnlyWhenThereIsText() {
    LineEditor editor = new;
    test:assertEquals(press(editor, "d", ctrl = true), "ignored", "empty: the program decides (end of input)");
    typed(editor, "ab");
    EditResult _ = press(editor, "left");
    test:assertEquals(press(editor, "d", ctrl = true), "edited");
    test:assertEquals(editor.text(), "a");
}

// ---- 2.1 submit and multi-line ----------------------------------------------------------------------

@test:Config {}
function testEnterSubmitsAndEmptiesTheEditor() {
    LineEditor editor = new;
    typed(editor, "hello");
    EditResult result = press(editor, "enter");
    test:assertEquals(result, <Submitted>{text: "hello"});
    test:assertEquals(editor.text(), "");
    test:assertEquals(editor.cursor(), 0);
}

@test:Config {}
function testAltEnterAndCtrlJInsertALineBreak() {
    LineEditor editor = new;
    typed(editor, "a");
    test:assertEquals(press(editor, "enter", alt = true), "edited");
    typed(editor, "b");
    test:assertEquals(press(editor, "j", ctrl = true), "edited");
    typed(editor, "c");
    test:assertEquals(editor.text(), "a\nb\nc");
}

@test:Config {}
function testASingleLineEditorIgnoresTheLineBreakKeys() {
    LineEditor editor = new (multiline = false);
    typed(editor, "a");
    test:assertEquals(press(editor, "enter", alt = true), "ignored");
    test:assertEquals(press(editor, "j", ctrl = true), "ignored");
    test:assertEquals(editor.text(), "a");
}

@test:Config {}
function testUpAndDownMoveBetweenLinesKeepingTheColumn() {
    LineEditor editor = new;
    typed(editor, "abcd");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "xy");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "123456");
    test:assertEquals(editor.cursor(), 14);
    EditResult _ = press(editor, "up");
    test:assertEquals(editor.cursor(), 7, "the second line is only two long: the cursor goes to its end");
    EditResult _ = press(editor, "up");
    test:assertEquals(editor.cursor(), 2, "column 2 of the first line");
    EditResult _ = press(editor, "down");
    test:assertEquals(editor.cursor(), 7, "column 2 of the second line is its end");
    EditResult _ = press(editor, "down");
    test:assertEquals(editor.cursor(), 10, "column 2 of the third line");
}

// ---- 2.2 paste --------------------------------------------------------------------------------------

@test:Config {}
function testAMultiLinePasteKeepsLineBreaksAndNormalisesCarriageReturns() {
    LineEditor editor = new;
    EditResult result = paste(editor, "x\r\ny\rz");
    test:assertEquals(result, "edited", "a paste never submits");
    test:assertEquals(editor.text(), "x\ny\nz");
    test:assertEquals(editor.cursor(), 5);
}

@test:Config {}
function testASingleLinePasteTurnsLineBreaksIntoSpaces() {
    LineEditor editor = new (multiline = false);
    EditResult result = paste(editor, "x\ny");
    test:assertEquals(result, "edited");
    test:assertEquals(editor.text(), "x y");
}

@test:Config {}
function testAPasteGoesInAtTheCursorAsOneInsertion() {
    LineEditor editor = new;
    typed(editor, "ad");
    EditResult _ = press(editor, "left");
    EditResult _ = paste(editor, "bc");
    test:assertEquals(editor.text(), "abcd");
    test:assertEquals(editor.cursor(), 3);
}

@test:Config {}
function testAPasteDropsControlCharactersAndExpandsTabs() {
    LineEditor editor = new;
    EditResult _ = paste(editor, "a\u{1b}[31mb\tc\u{7f}");
    test:assertEquals(editor.text(), "a[31mb    c");
}

// ---- 2.3 history ----------------------------------------------------------------------------------

function submitText(LineEditor editor, string value) {
    typed(editor, value);
    EditResult _ = press(editor, "enter");
}

@test:Config {}
function testUpAndDownWalkThroughTheHistory() {
    LineEditor editor = new;
    submitText(editor, "one");
    submitText(editor, "two");
    EditResult _ = press(editor, "up", times = 2);
    test:assertEquals(editor.text(), "one");
    EditResult _ = press(editor, "down");
    test:assertEquals(editor.text(), "two");
    EditResult _ = press(editor, "up", times = 5);
    test:assertEquals(editor.text(), "one", "the oldest entry is where it stops");
    test:assertEquals(editor.cursor(), 3, "the cursor goes to the end of the recalled text");
}

@test:Config {}
function testTheDraftIsKeptWhileWalkingTheHistory() {
    LineEditor editor = new;
    submitText(editor, "one");
    typed(editor, "dra");
    EditResult _ = press(editor, "up");
    test:assertEquals(editor.text(), "one");
    EditResult _ = press(editor, "down");
    test:assertEquals(editor.text(), "dra");
    EditResult _ = press(editor, "down");
    test:assertEquals(editor.text(), "dra", "nothing newer than the draft");
}

@test:Config {}
function testBlankTextAndRepeatsAreNotAddedToTheHistory() {
    LineEditor editor = new;
    submitText(editor, "one");
    submitText(editor, "one");
    submitText(editor, "   ");
    submitText(editor, "two");
    submitText(editor, "one");
    test:assertEquals(editor.history(), ["one", "two", "one"]);
}

@test:Config {}
function testTheHistoryIsLimitedAndCanBeSeeded() {
    LineEditor editor = new (history = ["a", "b", "c"], maxHistory = 3);
    submitText(editor, "d");
    test:assertEquals(editor.history(), ["b", "c", "d"]);
    LineEditor single = new (multiline = false, history = ["x\ny"]);
    EditResult _ = press(single, "up");
    test:assertEquals(single.text(), "x y", "a single-line editor never holds a line break");
}

@test:Config {}
function testUpOnALaterLineMovesTheCursorInsteadOfWalkingTheHistory() {
    LineEditor editor = new (history = ["old"]);
    typed(editor, "a");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "b");
    EditResult _ = press(editor, "up");
    test:assertEquals(editor.text(), "a\nb", "still the draft");
    EditResult _ = press(editor, "up");
    test:assertEquals(editor.text(), "old", "from the first line it walks the history");
    EditResult _ = press(editor, "down");
    test:assertEquals(editor.text(), "a\nb");
}

// ---- 3.1 drawing --------------------------------------------------------------------------------------

@test:Config {}
function testAnEmptyEditorShowsThePromptAndACursor() {
    LineEditor editor = new;
    text:Span[][] lines = editor.render(20);
    test:assertEquals(plain(lines), ["> " + " "]);
    test:assertEquals(reversed(lines), [" "]);
}

@test:Config {}
function testTheCursorIsTheCharacterUnderItInReverseVideo() {
    LineEditor editor = new;
    typed(editor, "abc");
    EditResult _ = press(editor, "left", times = 2);
    text:Span[][] lines = editor.render(20, "> ", {bold: true});
    test:assertEquals(plain(lines), ["> abc"]);
    test:assertEquals(reversed(lines), ["b"]);
    text:Style bold = {bold: true};
    text:Style boldReversed = {bold: true, reverse: true};
    text:Span[] expected = [{text: "> "}, {text: "a", style: bold}, {text: "b", style: boldReversed}, {text: "c", style: bold}];
    test:assertEquals(lines[0], expected);
}

@test:Config {}
function testTheCursorAtTheEndIsAReverseSpace() {
    LineEditor editor = new;
    typed(editor, "ab");
    text:Span[][] lines = editor.render(20);
    test:assertEquals(plain(lines), ["> ab "]);
    test:assertEquals(reversed(lines), [" "]);
}

@test:Config {}
function testLongTextWrapsByWidthAndTheCursorIsOnTheRightRow() {
    LineEditor editor = new;
    typed(editor, "abcdefgh");
    // width 6 and a prompt of 2 leave 4 columns
    text:Span[][] atEnd = editor.render(6);
    test:assertEquals(plain(atEnd), ["> abcd", "  efgh", "   "], "a full last row puts the end cursor on a row of its own");
    test:assertEquals(reversed(atEnd), ["", "", " "]);
    EditResult _ = press(editor, "left", times = 3);
    text:Span[][] inside = editor.render(6);
    test:assertEquals(plain(inside), ["> abcd", "  efgh"]);
    test:assertEquals(reversed(inside), ["", "f"]);
}

@test:Config {}
function testLaterLinesAreIndentedByThePromptWidth() {
    LineEditor editor = new;
    typed(editor, "a");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "b");
    EditResult _ = press(editor, "enter", alt = true);
    text:Span[][] lines = editor.render(20, ">> ");
    test:assertEquals(plain(lines), [">> a", "   b", "    "]);
    test:assertEquals(reversed(lines), ["", "", " "]);
}

@test:Config {}
function testAWideCharacterIsNeverSplitAcrossRows() {
    LineEditor editor = new;
    typed(editor, "ab日");
    // width 5 and a prompt of 2 leave 3 columns: the wide character does not fit after "ab"
    text:Span[][] lines = editor.render(5);
    test:assertEquals(plain(lines), ["> ab", "  日 "]);
    test:assertEquals(reversed(lines), ["", " "]);
}

@test:Config {}
function testACursorBetweenLinesSitsOnTheBreak() {
    LineEditor editor = new;
    typed(editor, "ab");
    EditResult _ = press(editor, "enter", alt = true);
    typed(editor, "cd");
    EditResult _ = press(editor, "up");
    EditResult _ = press(editor, "end");
    text:Span[][] lines = editor.render(20);
    test:assertEquals(plain(lines), ["> ab ", "  cd"]);
    test:assertEquals(reversed(lines), [" ", ""], "the cursor is a reverse space at the end of line one");
}

@test:Config {}
function testATextWithAnAccentDrawsTheLetterAndItsAccentTogether() {
    LineEditor editor = new;
    typed(editor, "e\u{301}x");
    EditResult _ = press(editor, "left");
    text:Span[][] lines = editor.render(20);
    test:assertEquals(plain(lines), ["> e\u{301}x"]);
    test:assertEquals(reversed(lines), ["x"]);
}
