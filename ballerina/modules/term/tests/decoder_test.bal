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

// Feeds bytes to the decoder and returns the events.
function decode(int[] bytes, boolean giveUp = false) returns InputEvent[] {
    return decodeInput(bytes, giveUp).events;
}

function key(string:Char|NamedKey key, boolean ctrl = false, boolean alt = false, boolean shift = false) returns KeyEvent {
    return {kind: "key", key, ctrl, alt, shift};
}

@test:Config {}
function testPrintableCharacters() {
    test:assertEquals(decode([0x61, 0x5A, 0x20, 0x7E]), [key("a"), key("Z"), key(" "), key("~")]);
}

@test:Config {}
function testUtf8Characters() {
    test:assertEquals(decode([0xC3, 0xA9]), [key("é")]);
    test:assertEquals(decode([0xE6, 0x97, 0xA5]), [key("日")]);
    test:assertEquals(decode([0xF0, 0x9F, 0x98, 0x80]), [key("😀")]);
}

@test:Config {}
function testAPartialUtf8CharacterWaitsForTheRest() {
    DecodeResult first = decodeInput([0x61, 0xE6, 0x97], false);
    test:assertEquals(first.events, [key("a")]);
    test:assertEquals(first.rest, [0xE6, 0x97]);
    DecodeResult second = decodeInput([...first.rest, 0xA5], false);
    test:assertEquals(second.events, [key("日")]);
    test:assertEquals(second.rest, []);
}

@test:Config {}
function testInvalidUtf8IsDropped() {
    test:assertEquals(decode([0xFF, 0x61, 0x80, 0x62]), [key("a"), key("b")]);
    test:assertEquals(decodeInput([0xE6, 0x97], true).rest, []);
}

@test:Config {}
function testControlKeys() {
    test:assertEquals(decode([0x03]), [key("c", ctrl = true)]);
    test:assertEquals(decode([0x01, 0x1A]), [key("a", ctrl = true), key("z", ctrl = true)]);
    test:assertEquals(decode([0x00]), [key(" ", ctrl = true)]);
    test:assertEquals(decode([0x1F]), [key("_", ctrl = true)]);
}

@test:Config {}
function testEditingKeys() {
    test:assertEquals(decode([0x0D]), [key("enter")]);
    test:assertEquals(decode([0x09]), [key("tab")]);
    test:assertEquals(decode([0x7F]), [key("backspace")]);
}

@test:Config {}
function testArrowKeys() {
    test:assertEquals(decode([0x1B, 0x5B, 0x41]), [key("up")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x42]), [key("down")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x43]), [key("right")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x44]), [key("left")]);
    // application cursor mode (SS3)
    test:assertEquals(decode([0x1B, 0x4F, 0x41]), [key("up")]);
}

@test:Config {}
function testModifiedArrowKeys() {
    test:assertEquals(decode([0x1B, 0x5B, 0x31, 0x3B, 0x35, 0x43]), [key("right", ctrl = true)]);
    test:assertEquals(decode([0x1B, 0x5B, 0x31, 0x3B, 0x32, 0x41]), [key("up", shift = true)]);
    test:assertEquals(decode([0x1B, 0x5B, 0x31, 0x3B, 0x33, 0x44]), [key("left", alt = true)]);
    test:assertEquals(decode([0x1B, 0x5B, 0x31, 0x3B, 0x36, 0x42]), [key("down", ctrl = true, shift = true)]);
}

@test:Config {}
function testNavigationAndFunctionKeys() {
    test:assertEquals(decode([0x1B, 0x5B, 0x48]), [key("home")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x46]), [key("end")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x33, 0x7E]), [key("delete")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x35, 0x7E]), [key("pageUp")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x36, 0x7E]), [key("pageDown")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x32, 0x7E]), [key("insert")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x31, 0x35, 0x7E]), [key("f5")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x32, 0x34, 0x7E]), [key("f12")]);
    test:assertEquals(decode([0x1B, 0x4F, 0x50]), [key("f1")]);
    test:assertEquals(decode([0x1B, 0x5B, 0x31, 0x3B, 0x32, 0x50]), [key("f1", shift = true)]);
    test:assertEquals(decode([0x1B, 0x5B, 0x33, 0x3B, 0x35, 0x7E]), [key("delete", ctrl = true)]);
}

@test:Config {}
function testShiftTab() {
    test:assertEquals(decode([0x1B, 0x5B, 0x5A]), [key("tab", shift = true)]);
}

@test:Config {}
function testAltKeys() {
    test:assertEquals(decode([0x1B, 0x78]), [key("x", alt = true)]);
    test:assertEquals(decode([0x1B, 0x7F]), [key("backspace", alt = true)]);
    test:assertEquals(decode([0x1B, 0x0D]), [key("enter", alt = true)]);
    test:assertEquals(decode([0x1B, 0x03]), [key("c", ctrl = true, alt = true)]);
}

@test:Config {}
function testALoneEscapeWaitsAndThenBecomesEscape() {
    DecodeResult waiting = decodeInput([0x1B], false);
    test:assertEquals(waiting.events, []);
    test:assertEquals(waiting.rest, [0x1B]);
    DecodeResult given = decodeInput([0x1B], true);
    test:assertEquals(given.events, [key("escape")]);
    test:assertEquals(given.rest, []);
}

@test:Config {}
function testASequenceSplitAcrossReadsIsCompletedLater() {
    DecodeResult first = decodeInput([0x61, 0x1B, 0x5B], false);
    test:assertEquals(first.events, [key("a")]);
    test:assertEquals(first.rest, [0x1B, 0x5B]);
    DecodeResult second = decodeInput([...first.rest, 0x41], false);
    test:assertEquals(second.events, [key("up")]);
    test:assertEquals(second.rest, []);
    // and split in the middle of the parameters
    DecodeResult third = decodeInput([0x1B, 0x5B, 0x31, 0x3B], false);
    test:assertEquals(third.events, []);
    test:assertEquals(decodeInput([...third.rest, 0x35, 0x41], false).events, [key("up", ctrl = true)]);
}

@test:Config {}
function testAnIncompleteSequenceIsAbandonedOnTimeout() {
    DecodeResult result = decodeInput([0x1B, 0x5B, 0x31, 0x3B], true);
    test:assertEquals(result.events[0], key("escape"));
    // the rest of the bytes are then read as ordinary characters
    test:assertEquals(result.events.length(), 4);
}

@test:Config {}
function testEscapeFollowedByASequenceIsTwoKeys() {
    test:assertEquals(decode([0x1B, 0x1B, 0x5B, 0x41]), [key("escape"), key("up")]);
}

@test:Config {}
function testBracketedPaste() {
    int[] pasted = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E, 0x68, 0x69, 0x0A, 0xC3, 0xA9, 0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E];
    DecodeResult result = decodeInput(pasted, false);
    test:assertEquals(result.events, [<PasteEvent>{kind: "paste", text: "hi\né"}]);
    test:assertEquals(result.rest, []);
}

@test:Config {}
function testAPasteThatIsStillArrivingIsNotEmitted() {
    int[] opening = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E, 0x68, 0x69];
    test:assertEquals(decodeInput(opening, false).events, []);
    // even when the silence timeout fires: a paste is only complete at its end marker
    DecodeResult stalled = decodeInput(opening, true);
    test:assertEquals(stalled.events, []);
    test:assertEquals(stalled.rest, opening);
    DecodeResult done = decodeInput([...opening, 0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E, 0x61], false);
    test:assertEquals(done.events, [<PasteEvent>{kind: "paste", text: "hi"}, key("a")]);
}

@test:Config {}
function testAnEscapeInsideAPasteIsKept() {
    int[] pasted = [0x1B, 0x5B, 0x32, 0x30, 0x30, 0x7E, 0x1B, 0x5B, 0x41, 0x1B, 0x5B, 0x32, 0x30, 0x31, 0x7E];
    test:assertEquals(decode(pasted), [<PasteEvent>{kind: "paste", text: "\u{1b}[A"}]);
}

@test:Config {}
function testResizeNotification() {
    // ESC [ 48 ; 30 ; 100 ; 0 ; 0 t
    int[] sequence = [0x1B, 0x5B, 0x34, 0x38, 0x3B, 0x33, 0x30, 0x3B, 0x31, 0x30, 0x30, 0x3B, 0x30, 0x3B, 0x30, 0x74];
    test:assertEquals(decode(sequence), [<ResizeEvent>{kind: "resize", width: 100, height: 30}]);
}

@test:Config {}
function testTerminalRepliesAndMouseReportsAreNotInput() {
    // focus in, SGR mouse press, a cursor position report, then a real key
    int[] bytes = [0x1B, 0x5B, 0x49,
        0x1B, 0x5B, 0x3C, 0x30, 0x3B, 0x31, 0x30, 0x3B, 0x35, 0x4D,
        0x1B, 0x5B, 0x32, 0x34, 0x3B, 0x38, 0x30, 0x52,
        0x71];
    test:assertEquals(decode(bytes), [key("q")]);
}

@test:Config {}
function testManyEventsInOneRead() {
    test:assertEquals(decode([0x68, 0x1B, 0x5B, 0x41, 0x69, 0x0D]), [key("h"), key("up"), key("i"), key("enter")]);
}
