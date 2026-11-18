// Copyright (c) 2026, WSO2 LLC. (https://www.wso2.com).
//
// WSO2 LLC. licenses this file to you under the Apache License,
// Version 2.0 (the "License"); you may not use this file except
// in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
// KIND, either express or implied.  See the License for the
// specific language governing permissions and limitations
// under the License.

import ayesha/termui.term;
import ballerina/test;

// Tests for the bottom-anchored live region. The in-memory terminal answers cursor position requests
// from its virtual screen, so the whole layout can be checked without a real terminal.

function anchoredRenderer(int width, int height, boolean reflow = true) returns [term:FakeTerminal, InlineRenderer] {
    term:FakeTerminal terminal = new (width, height);
    return [terminal, new InlineRenderer(terminal, width, height, true, reflow, true)];
}

// Output that was on screen before the renderer started, leaving the cursor at the start of a fresh row.
function earlier(term:FakeTerminal terminal, string... lines) returns error? {
    foreach string line in lines {
        check terminal.write(line + "\r\n");
    }
}

function blankRows(int count) returns string[] {
    string[] out = [];
    foreach int _ in 0 ..< count {
        out.push("");
    }
    return out;
}

// A terminal that cannot tell where its cursor is: it forwards everything to a fake and does not offer
// the capability.
isolated class NoCursor {
    *term:Terminal;

    private final term:FakeTerminal inner;

    isolated function init(term:FakeTerminal inner) {
        self.inner = inner;
    }

    public isolated function acquire() returns error? {
        return self.inner.acquire();
    }

    public isolated function release() returns error? {
        return self.inner.release();
    }

    public isolated function size() returns term:Size|error {
        return self.inner.size();
    }

    public isolated function nextEvent() returns term:InputEvent|error? {
        return self.inner.nextEvent();
    }

    public isolated function write(string data) returns error? {
        return self.inner.write(data);
    }
}

// ---- first draw --------------------------------------------------------------------------------

@test:Config {}
function testTheRegionIsPlacedOnTheLastRowsWhenThereIsRoom() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b"));
    test:assertEquals(terminal.screenLines(), ["banner", ...blankRows(9), "a", "b"]);
    test:assertEquals(terminal.scrollbackLines(), [], "nothing scrolled");
    test:assertEquals(terminal.cursorPosition(), [11, 0], "the cursor rests on the last row");
}

@test:Config {}
function testTheScreenScrollsByOnlyTheMissingRowsNearTheBottom() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 6);
    check earlier(terminal, "l0", "l1", "l2", "l3", "l4");
    check renderer.draw(rows("x", "y", "z"));
    test:assertEquals(terminal.screenLines(), ["l2", "l3", "l4", "x", "y", "z"]);
    test:assertEquals(terminal.scrollbackLines(), ["l0", "l1"], "exactly the missing rows scrolled, nothing was overwritten");
}

@test:Config {}
function testAnAnchoredRegionOnAnEmptyScreenFillsTheLastRows() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 5);
    check renderer.draw(rows("only"));
    test:assertEquals(terminal.screenLines(), [...blankRows(4), "only"]);
    test:assertEquals(terminal.scrollbackLines(), []);
}

@test:Config {}
function testWithoutTheOptionTheRegionStartsOnTheCursorRow() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = inline(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b"));
    test:assertEquals(terminal.screenLines().slice(0, 3), ["banner", "a", "b"]);
}

@test:Config {}
function testATerminalThatCannotReportItsCursorIsDrawnAsBefore() returns error? {
    term:FakeTerminal quiet = new (20, 12);
    term:FakeTerminal reference = new (20, 12);
    InlineRenderer anchoredButBlind = new (new NoCursor(quiet), 20, 12, true, true, true);
    InlineRenderer plain = new (reference, 20, 12);
    foreach term:FakeTerminal terminal in [quiet, reference] {
        check earlier(terminal, "banner");
    }
    foreach InlineRenderer renderer in [anchoredButBlind, plain] {
        check renderer.draw(rows("a", "b"));
        check renderer.draw(rows("a", "b", "c"));
        check renderer.commitProse(rows("done"));
        check renderer.draw(rows("a"));
    }
    test:assertEquals(quiet.writes(), reference.writes(), "no cursor report: the output is exactly the unanchored output");
    test:assertEquals(quiet.screenLines(), reference.screenLines());
}

// ---- growth and shrink -------------------------------------------------------------------------

@test:Config {}
function testARegionGrowsUpwardIntoTheBlankRows() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("AAA", "BBB"));
    check renderer.draw(rows("new1", "new2", "AAA", "BBB"));
    test:assertEquals(terminal.screenLines(), ["banner", ...blankRows(7), "new1", "new2", "AAA", "BBB"]);
    test:assertEquals(terminal.scrollbackLines(), [], "nothing scrolled");
    string[] writes = terminal.writes();
    test:assertFalse(writes[writes.length() - 1].includes("AAA"), "the rows that did not change are not written again");
}

@test:Config {}
function testGrowthBeyondTheBlankRowsScrollsOnlyForTheExcess() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 8);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b")); // five blank rows
    check renderer.draw(rows("1", "2", "3", "4", "5", "6", "7", "8"));
    test:assertEquals(terminal.screenLines(), ["1", "2", "3", "4", "5", "6", "7", "8"]);
    test:assertEquals(terminal.scrollbackLines(), ["banner"], "one row scrolled: the one the region lacked");
}

@test:Config {}
function testAShrinkingRegionKeepsTheLastRow() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b", "c", "d"));
    check renderer.draw(rows("c", "d"));
    test:assertEquals(terminal.screenLines(), ["banner", ...blankRows(9), "c", "d"]);
    test:assertEquals(terminal.cursorPosition(), [11, 0], "no blank row below the region");
    check renderer.draw(rows("c", "e"));
    test:assertEquals(terminal.screenLines()[11], "e");
}

@test:Config {}
function testTheBlankRowsAreReusedAfterAShrink() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b", "c", "d"));
    check renderer.draw(rows("d"));
    check renderer.commitProse(rows("one", "two", "three"));
    test:assertEquals(terminal.screenLines(), ["banner", "one", "two", "three", ...blankRows(7), "d"]);
    test:assertEquals(terminal.scrollbackLines(), []);
}

@test:Config {}
function testAnEmptyRegionIsAnchoredAgainWhenItComesBack() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b"));
    check renderer.draw([]);
    test:assertEquals(terminal.screenLines(), ["banner", ...blankRows(11)]);
    check renderer.draw(rows("x"));
    test:assertEquals(terminal.screenLines(), ["banner", ...blankRows(10), "x"]);
    test:assertEquals(terminal.scrollbackLines(), []);
}

// ---- committed output --------------------------------------------------------------------------

@test:Config {}
function testCommittedOutputFillsTheBlankRowsWithoutMovingTheRegion() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("AAA", "BBB"));
    check renderer.commitProse(rows("hello", "world"));
    test:assertEquals(terminal.screenLines(), ["banner", "hello", "world", ...blankRows(7), "AAA", "BBB"]);
    test:assertEquals(terminal.scrollbackLines(), []);
    string[] writes = terminal.writes();
    test:assertFalse(writes[writes.length() - 1].includes("AAA"), "the region is not touched by a commit that fits");
}

@test:Config {}
function testACommitLongerThanTheBlankRowsScrollsTheRest() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 8);
    check earlier(terminal, "banner");
    check renderer.draw(rows("A1", "B1")); // five blank rows
    check renderer.commitProse(rows("c1", "c2", "c3", "c4", "c5", "c6", "c7"));
    test:assertEquals(terminal.screenLines(), ["c2", "c3", "c4", "c5", "c6", "c7", "A1", "B1"]);
    test:assertEquals(terminal.scrollbackLines(), ["banner", "c1"], "no blank row went into the scrollback");
}

@test:Config {}
function testWrappedProseCountsAllItsRows() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(10, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("AAA", "BBB"));
    check renderer.commitProse(rows("abcdefghijklmnopqrstuvwxy"));
    test:assertEquals(terminal.screenLines(), ["banner", "abcdefghij", "klmnopqrst", "uvwxy", ...blankRows(6), "AAA", "BBB"]);
    check renderer.commitProse(rows("next"));
    test:assertEquals(terminal.screenLines()[4], "next", "the next commit follows directly");
    test:assertEquals(terminal.scrollbackLines(), []);
}

@test:Config {}
function testBlocksAreCommittedIntoTheBlankRowsToo() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(10, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("AAA"));
    check renderer.commitBlock(rows("abcdefghijklmno"));
    test:assertEquals(terminal.screenLines().slice(0, 3), ["banner", "abcdefghij", "klmno"]);
    test:assertEquals(terminal.screenLines()[11], "AAA");
}

@test:Config {}
function testNonAsciiTextIsMeasuredNotCounted() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("AAA", "BBB"));
    check renderer.commitProse(rows("héllo wörld"));
    check renderer.commitProse(rows("next"));
    test:assertEquals(terminal.screenLines(), ["banner", "héllo wörld", "next", ...blankRows(7), "AAA", "BBB"]);
    test:assertEquals(terminal.scrollbackLines(), []);
}

@test:Config {}
function testWideCharactersThatWrapAreMeasured() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(5, 12);
    check earlier(terminal, "head");
    check renderer.draw(rows("AAA"));
    check renderer.commitProse(rows("日本語"));
    check renderer.commitProse(rows("next"));
    test:assertEquals(terminal.screenLines().slice(0, 4), ["head", "日本", "語", "next"]);
    test:assertEquals(terminal.screenLines()[11], "AAA");
}

// ---- after the blank rows are used up ----------------------------------------------------------

@test:Config {}
function testOnceTheBlankRowsAreUsedUpOutputScrollsIntoTheScrollback() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 8);
    check earlier(terminal, "banner");
    check renderer.draw(rows("R1", "R2"));
    string[] expected = ["banner"];
    foreach int n in 1 ... 20 {
        string line = "line" + n.toString();
        expected.push(line);
        check renderer.commitProse(rows(line));
        string[] screen = terminal.screenLines();
        test:assertEquals(screen.slice(6), ["R1", "R2"], "the region stays on the last rows after commit " + line);
    }
    string[] seen = [];
    foreach string line in [...terminal.scrollbackLines(), ...terminal.screenLines()] {
        if line != "" {
            seen.push(line);
        }
    }
    test:assertEquals(seen, [...expected, "R1", "R2"], "everything is there once, in order, banner first");
    foreach string line in terminal.scrollbackLines() {
        test:assertNotEquals(line, "", "no blank row reached the scrollback");
    }
}

@test:Config {}
function testTheRegionCanChangeAfterTheBlankRowsAreGone() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 6);
    check earlier(terminal, "l0", "l1", "l2", "l3");
    check renderer.draw(rows("a", "b")); // r = 4, region 2 rows: no blank rows
    check renderer.draw(rows("a", "b", "c"));
    test:assertEquals(terminal.screenLines(), ["l1", "l2", "l3", "a", "b", "c"]);
    check renderer.draw(rows("c"));
    test:assertEquals(terminal.screenLines()[5], "c");
    check renderer.commitProse(rows("x"));
    test:assertEquals(terminal.screenLines()[5], "c");
    test:assertEquals(terminal.scrollbackLines()[0], "l0");
}

// ---- resize ------------------------------------------------------------------------------------

// `keepsLayout` is false when narrowing a reflowing terminal: it re-wraps the old region into more rows, which
// pushes the top of the screen (the banner, and some blank rows) into its scrollback, whatever the application does.
function anchoredResizeScenario(boolean reflow, int newWidth, boolean keepsLayout = true) returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12, reflow);
    check earlier(terminal, "banner");
    check renderer.draw(rows("abcdefghijklmnopqrst", "second row of region", "third"));
    terminal.resize(newWidth, 12, reflow);
    check renderer.resize(newWidth, 12);
    check renderer.draw(rows("NEW1", "NEW2"));
    string[] screen = terminal.screenLines();
    test:assertEquals(screen.slice(10), ["NEW1", "NEW2"], "the new region is on the last rows");
    string text = terminal.screenText();
    test:assertFalse(text.includes("abcd"), "no stale row of the old region may remain: " + text);
    test:assertFalse(text.includes("second"), "no stale row of the old region may remain: " + text);
    test:assertFalse(text.includes("third"), "no stale row of the old region may remain: " + text);
    test:assertTrue([...terminal.scrollbackLines(), ...screen].indexOf("banner") is int, "earlier output is kept");
    if keepsLayout {
        test:assertEquals(screen[0], "banner", "earlier output is untouched");
        foreach int row in 1 ... 9 {
            test:assertEquals(screen[row], "", "only blank rows between the output and the region");
        }
    }
    check renderer.commitProse(rows("after"));
    screen = terminal.screenLines();
    test:assertEquals(screen.slice(10), ["NEW1", "NEW2"], "a commit leaves the region where it is");
    test:assertTrue(screen.indexOf("after") is int, "the committed text is on screen");
    if keepsLayout {
        test:assertEquals(screen[1], "after", "the blank rows are used again after the resize");
    }
}

@test:Config {}
function testNarrowingAReflowingTerminalAnchorsAgain() returns error? {
    check anchoredResizeScenario(true, 8, false);
}

@test:Config {}
function testWideningAReflowingTerminalAnchorsAgain() returns error? {
    check anchoredResizeScenario(true, 40);
}

@test:Config {}
function testNarrowingATerminalThatCutsTextAnchorsAgain() returns error? {
    check anchoredResizeScenario(false, 8);
}

@test:Config {}
function testWideningATerminalThatCutsTextAnchorsAgain() returns error? {
    check anchoredResizeScenario(false, 40);
}

// ---- full screen -------------------------------------------------------------------------------

@test:Config {}
function testAnchoringSurvivesAFullScreenVisit() returns error? {
    [term:FakeTerminal, InlineRenderer] [terminal, renderer] = anchoredRenderer(20, 12);
    check earlier(terminal, "banner");
    check renderer.draw(rows("a", "b"));
    check renderer.enterFullScreen();
    check renderer.draw(rows("full screen"));
    check renderer.leaveFullScreen();
    check renderer.draw(rows("a2", "b2"));
    check renderer.commitProse(rows("hi"));
    test:assertEquals(terminal.screenLines(), ["banner", "hi", ...blankRows(8), "a2", "b2"]);
}
