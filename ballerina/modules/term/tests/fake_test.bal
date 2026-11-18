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
function testScriptedKeysArriveInOrder() returns error? {
    FakeTerminal terminal = new;
    terminal.pushText("hi");
    terminal.pushKey("up", ctrl = true);
    terminal.pushEvent({text: "pasted\nlines"});
    test:assertEquals(check terminal.nextEvent(), <KeyEvent>{key: "h"});
    test:assertEquals(check terminal.nextEvent(), <KeyEvent>{key: "i"});
    test:assertEquals(check terminal.nextEvent(), <KeyEvent>{key: "up", ctrl: true});
    test:assertEquals(check terminal.nextEvent(), <PasteEvent>{text: "pasted\nlines"});
    test:assertEquals(check terminal.nextEvent(), ());
    test:assertEquals(check terminal.nextEvent(), ());
}

@test:Config {}
function testRenderedTextCanBeReadBack() returns error? {
    FakeTerminal terminal = new (20, 5);
    check terminal.write("hello\r\nworld");
    test:assertEquals(terminal.screenLines(), ["hello", "world", "", "", ""]);
    test:assertEquals(terminal.screenText(), "hello\nworld");
    test:assertEquals(terminal.cursorPosition(), [1, 5]);
}

@test:Config {}
function testLineFeedDoesNotReturnTheCursor() returns error? {
    FakeTerminal terminal = new (20, 5);
    check terminal.write("ab\ncd");
    test:assertEquals(terminal.screenLines()[0], "ab");
    test:assertEquals(terminal.screenLines()[1], "  cd");
}

@test:Config {}
function testCursorMovementAndOverwrite() returns error? {
    FakeTerminal terminal = new (20, 5);
    check terminal.write("abc\r\u{1b}[2CX");
    test:assertEquals(terminal.screenLines()[0], "abX");
    check terminal.write("\u{1b}[2;4Hq\u{1b}[1A\u{1b}[1Dz");
    test:assertEquals(terminal.screenLines()[0], "abXz");
    test:assertEquals(terminal.screenLines()[1], "   q");
}

@test:Config {}
function testEraseLineAndScreen() returns error? {
    FakeTerminal terminal = new (10, 4);
    check terminal.write("aaaa\r\nbbbb\r\ncccc");
    check terminal.write("\u{1b}[2;3H\u{1b}[K");
    test:assertEquals(terminal.screenLines()[1], "bb");
    check terminal.write("\u{1b}[1;1H\u{1b}[2K");
    test:assertEquals(terminal.screenLines()[0], "");
    check terminal.write("\u{1b}[2J");
    test:assertEquals(terminal.screenText(), "");
}

@test:Config {}
function testEraseBelowTheCursor() returns error? {
    FakeTerminal terminal = new (10, 4);
    check terminal.write("aaaa\r\nbbbb\r\ncccc\u{1b}[2;2H\u{1b}[J");
    test:assertEquals(terminal.screenLines(), ["aaaa", "b", "", ""]);
}

@test:Config {}
function testScrollingMovesLinesIntoTheScrollback() returns error? {
    FakeTerminal terminal = new (10, 3);
    check terminal.write("1\r\n2\r\n3\r\n4\r\n5");
    test:assertEquals(terminal.scrollbackLines(), ["1", "2"]);
    test:assertEquals(terminal.screenLines(), ["3", "4", "5"]);
}

@test:Config {}
function testTextWrapsAtTheRightEdge() returns error? {
    FakeTerminal terminal = new (5, 4);
    check terminal.write("abcdefg");
    test:assertEquals(terminal.screenLines(), ["abcde", "fg", "", ""]);
}

@test:Config {}
function testWideCharactersTakeTwoCellsAndWrapWhole() returns error? {
    FakeTerminal terminal = new (5, 4);
    check terminal.write("日本語");
    test:assertEquals(terminal.screenLines()[0], "日本");
    test:assertEquals(terminal.screenLines()[1], "語");
}

@test:Config {}
function testStylesAndModesDoNotChangeTheText() returns error? {
    FakeTerminal terminal = new (20, 3);
    check terminal.write("\u{1b}[?25l\u{1b}[1;31mred\u{1b}[0m \u{1b}]0;title\u{07}ok\u{1b}[?25h");
    test:assertEquals(terminal.screenLines()[0], "red ok");
}

@test:Config {}
function testEveryWriteIsLoggedWhole() returns error? {
    FakeTerminal terminal = new;
    check terminal.write("frame one");
    check terminal.write("frame two");
    test:assertEquals(terminal.writes(), ["frame one", "frame two"]);
}

@test:Config {}
function testAcquireAndRelease() returns error? {
    FakeTerminal terminal = new;
    test:assertFalse(terminal.isAcquired());
    check terminal.acquire();
    test:assertTrue(terminal.isAcquired());
    test:assertTrue(terminal.acquire() is error);
    check terminal.release();
    test:assertFalse(terminal.isAcquired());
}

@test:Config {}
function testResizeUpdatesTheSizeAndSendsAnEvent() returns error? {
    FakeTerminal terminal = new (80, 24);
    terminal.resize(40, 10);
    test:assertEquals(check terminal.size(), <Size>{width: 40, height: 10});
    test:assertEquals(check terminal.nextEvent(), <ResizeEvent>{width: 40, height: 10});
}

@test:Config {}
function testNarrowingReflowsTextThatWrappedAutomatically() returns error? {
    FakeTerminal terminal = new (10, 6);
    check terminal.write("abcdefghijkl\r\nxy");
    test:assertEquals(terminal.screenLines()[0], "abcdefghij");
    test:assertEquals(terminal.screenLines()[1], "kl");
    terminal.resize(4, 6);
    test:assertEquals(terminal.screenLines().slice(0, 5), ["abcd", "efgh", "ijkl", "xy", ""]);
}

@test:Config {}
function testWideningJoinsRowsThatWrappedAutomatically() returns error? {
    FakeTerminal terminal = new (5, 6);
    check terminal.write("abcdefgh\r\nxy");
    terminal.resize(20, 6);
    test:assertEquals(terminal.screenLines().slice(0, 3), ["abcdefgh", "xy", ""]);
}

@test:Config {}
function testHardLineBreaksAreNotJoinedByReflow() returns error? {
    FakeTerminal terminal = new (5, 6);
    check terminal.write("abc\r\ndef");
    terminal.resize(20, 6);
    test:assertEquals(terminal.screenLines().slice(0, 3), ["abc", "def", ""]);
}

@test:Config {}
function testWithoutReflowNarrowingCutsTheText() returns error? {
    FakeTerminal terminal = new (10, 6);
    check terminal.write("abcdefghijkl");
    terminal.resize(4, 6, reflow = false);
    test:assertEquals(terminal.screenLines().slice(0, 3), ["abcd", "kl", ""]);
}

@test:Config {}
function testTheCursorStaysOnItsCharacterWhenReflowing() returns error? {
    FakeTerminal terminal = new (10, 6);
    check terminal.write("abcdefghijkl\r\nxy");
    terminal.resize(4, 6);
    test:assertEquals(terminal.cursorPosition(), [3, 2]);
}

@test:Config {}
function testReflowPushesRowsThatNoLongerFitIntoTheScrollback() returns error? {
    FakeTerminal terminal = new (10, 3);
    check terminal.write("aaaaaaaaaa\r\nbbbbbbbbbb\r\ncc");
    terminal.resize(5, 3);
    test:assertEquals(terminal.scrollbackLines().length() > 0, true);
    test:assertEquals(terminal.screenLines()[2], "cc");
}

@test:Config {}
function testTheAlternateScreenRestoresTheMainScreen() returns error? {
    FakeTerminal terminal = new (20, 4);
    check terminal.write("history\r\nline two");
    check terminal.write("\u{1b}[?1049h");
    test:assertEquals(terminal.screenText(), "");
    check terminal.write("full screen app");
    test:assertEquals(terminal.screenText(), "full screen app");
    check terminal.write("\u{1b}[?1049l");
    test:assertEquals(terminal.screenText(), "history\nline two");
    test:assertEquals(terminal.cursorPosition(), [1, 8]);
}
