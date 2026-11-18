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

// Turns the bytes a terminal sends into input events. The decoder is a pure function over the bytes
// received so far: it consumes every complete event and returns the bytes it could not finish
// (a partial escape sequence or UTF-8 character), to be retried when more bytes arrive. A lone Esc
// cannot be told from the start of a sequence, so it stays pending until `giveUp` is set, which the
// caller does after a short silence.

// `report` is the cursor position reply found in the input, if one was expected and arrived.
type DecodeResult record {|
    InputEvent[] events;
    int[] rest;
    CursorPosition? report = ();
|};

type Parsed record {|
    int consumed;
    InputEvent? event = ();
    CursorPosition? report = ();
|};

const int ESC_BYTE = 0x1B;
const string PRINTABLE = " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~";
const string LOWERCASE = "abcdefghijklmnopqrstuvwxyz";
const string CONTROL_SYMBOLS = "\\]^_";
const string PASTE_END = "\u{1b}[201~";

isolated function printable(int code) returns string:Char {
    return <string:Char>PRINTABLE.substring(code - 0x20, code - 0x1F);
}

isolated function namedKey(NamedKey key, boolean ctrl = false, boolean alt = false, boolean shift = false) returns KeyEvent {
    return {kind: "key", key, ctrl, alt, shift};
}

// The key for a single byte below 0x80 (other than Esc).
isolated function keyForByte(int code) returns KeyEvent {
    if code >= 0x20 && code <= 0x7E {
        return {kind: "key", key: printable(code)};
    }
    if code == 0x09 {
        return namedKey("tab");
    }
    if code == 0x0D {
        return namedKey("enter");
    }
    if code == 0x7F || code == 0x08 {
        return namedKey("backspace");
    }
    if code == 0x00 {
        return {kind: "key", key: " ", ctrl: true};
    }
    if code >= 0x01 && code <= 0x1A {
        return {kind: "key", key: <string:Char>LOWERCASE.substring(code - 1, code), ctrl: true};
    }
    if code >= 0x1C && code <= 0x1F {
        return {kind: "key", key: <string:Char>CONTROL_SYMBOLS.substring(code - 0x1C, code - 0x1B), ctrl: true};
    }
    return namedKey("escape");
}

isolated function toBytes(int[] values) returns byte[] {
    byte[] bytes = [];
    foreach int value in values {
        bytes.push(<byte>value);
    }
    return bytes;
}

isolated function utf8Length(int lead) returns int {
    if lead >= 0xC2 && lead <= 0xDF {
        return 2;
    }
    if lead >= 0xE0 && lead <= 0xEF {
        return 3;
    }
    if lead >= 0xF0 && lead <= 0xF4 {
        return 4;
    }
    return 0;
}

isolated function decodeText(int[] values) returns string? {
    string|error text = string:fromBytes(toBytes(values));
    return text is string ? text : ();
}

isolated function parseNumbers(string params) returns int[] {
    int[] numbers = [];
    foreach string part in re `;`.split(params) {
        int|error value = int:fromString(part);
        numbers.push(value is int ? value : 0);
    }
    return numbers;
}

// Modifier parameter of a CSI key sequence: 1 plus a bit set (1 shift, 2 alt, 4 ctrl).
isolated function modifiers(int[] numbers, int index) returns [boolean, boolean, boolean] {
    int value = index < numbers.length() ? numbers[index] : 0;
    int bits = value > 1 ? value - 1 : 0;
    return [(bits & 1) != 0, (bits & 2) != 0, (bits & 4) != 0];
}

isolated function functionKey(int number) returns NamedKey? {
    match number {
        1 => {
            return "f1";
        }
        2 => {
            return "f2";
        }
        3 => {
            return "f3";
        }
        4 => {
            return "f4";
        }
    }
    return ();
}

isolated function tildeKey(int number) returns NamedKey? {
    match number {
        1|7 => {
            return "home";
        }
        2 => {
            return "insert";
        }
        3 => {
            return "delete";
        }
        4|8 => {
            return "end";
        }
        5 => {
            return "pageUp";
        }
        6 => {
            return "pageDown";
        }
        11 => {
            return "f1";
        }
        12 => {
            return "f2";
        }
        13 => {
            return "f3";
        }
        14 => {
            return "f4";
        }
        15 => {
            return "f5";
        }
        17 => {
            return "f6";
        }
        18 => {
            return "f7";
        }
        19 => {
            return "f8";
        }
        20 => {
            return "f9";
        }
        21 => {
            return "f10";
        }
        23 => {
            return "f11";
        }
        24 => {
            return "f12";
        }
    }
    return ();
}

// The event for a complete CSI sequence (ESC [ params terminator); () for sequences that are not input.
isolated function csiEvent(string params, string:Char terminator) returns InputEvent? {
    if params.startsWith("<") || params.startsWith("?") || params.startsWith(">") {
        return (); // mouse reports and terminal replies are not key input
    }
    int[] numbers = parseNumbers(params);
    [boolean, boolean, boolean] [shift, alt, ctrl] = modifiers(numbers, 1);
    match terminator {
        "A" => {
            return namedKey("up", ctrl, alt, shift);
        }
        "B" => {
            return namedKey("down", ctrl, alt, shift);
        }
        "C" => {
            return namedKey("right", ctrl, alt, shift);
        }
        "D" => {
            return namedKey("left", ctrl, alt, shift);
        }
        "H" => {
            return namedKey("home", ctrl, alt, shift);
        }
        "F" => {
            return namedKey("end", ctrl, alt, shift);
        }
        "Z" => {
            return namedKey("tab", false, false, true);
        }
        "P"|"Q"|"R"|"S" => {
            // F1 to F4 as ESC [ 1 ; m P. A bare "R" with other parameters is a cursor position report.
            int base = terminator == "P" ? 1 : terminator == "Q" ? 2 : terminator == "R" ? 3 : 4;
            if terminator == "R" && !(numbers.length() == 2 && numbers[0] == 1) {
                return ();
            }
            NamedKey? key = functionKey(base);
            return key is NamedKey ? namedKey(key, ctrl, alt, shift) : ();
        }
        "~" => {
            NamedKey? key = tildeKey(numbers.length() > 0 ? numbers[0] : 0);
            [boolean, boolean, boolean] [tildeShift, tildeAlt, tildeCtrl] = modifiers(numbers, 1);
            return key is NamedKey ? namedKey(key, tildeCtrl, tildeAlt, tildeShift) : ();
        }
        "t" => {
            // in-band resize notification: ESC [ 48 ; rows ; cols ; height ; width t
            if numbers.length() >= 3 && numbers[0] == 48 {
                return {kind: "resize", width: numbers[2], height: numbers[1]};
            }
            return ();
        }
    }
    return (); // focus events (I, O) and everything else
}

isolated function indexOfPasteEnd(int[] input, int searchFrom) returns int {
    string marker = PASTE_END;
    int[] pattern = [];
    foreach string:Char char in marker {
        pattern.push(char.toCodePointInt());
    }
    int last = input.length() - pattern.length();
    int i = searchFrom;
    while i <= last {
        boolean matches = true;
        foreach int offset in 0 ..< pattern.length() {
            if input[i + offset] != pattern[offset] {
                matches = false;
                break;
            }
        }
        if matches {
            return i;
        }
        i += 1;
    }
    return -1;
}

// Parses what starts with ESC at index `begin`. A consumed count of 0 means the sequence is not
// complete yet. With `giveUp` set, an incomplete sequence is given up on: the ESC alone is a key.
isolated function parseEscape(int[] input, int begin, boolean giveUp, boolean awaitingCursor = false) returns Parsed {
    int count = input.length();
    Parsed incomplete = giveUp ? {consumed: 1, event: namedKey("escape")} : {consumed: 0};
    if begin + 1 >= count {
        return incomplete;
    }
    int next = input[begin + 1];
    if next == 0x5B {
        int j = begin + 2;
        string params = "";
        while j < count {
            int code = input[j];
            if code >= 0x20 && code <= 0x3F {
                params += printable(code);
                j += 1;
                continue;
            }
            if code >= 0x40 && code <= 0x7E {
                string:Char terminator = printable(code);
                int length = j - begin + 1;
                if params == "200" && terminator == "~" {
                    int end = indexOfPasteEnd(input, begin + length);
                    if end < 0 {
                        return {consumed: 0}; // the paste is still arriving
                    }
                    string? text = decodeText(input.slice(begin + length, end));
                    return {consumed: end + PASTE_END.length() - begin, event: {kind: "paste", text: text ?: ""}};
                }
                if awaitingCursor && terminator == "R" {
                    // ESC [ row ; col R, one-based: the answer to a cursor position request. The same bytes are
                    // Ctrl+F3 when nothing was asked, so this is only recognized while a request is outstanding.
                    int[] numbers = parseNumbers(params);
                    if numbers.length() == 2 && re `[0-9]+;[0-9]+`.isFullMatch(params) {
                        return {consumed: length, report: {row: int:max(0, numbers[0] - 1), col: int:max(0, numbers[1] - 1)}};
                    }
                }
                return {consumed: length, event: csiEvent(params, terminator)};
            }
            return {consumed: j - begin}; // malformed: drop what was read
        }
        return incomplete;
    }
    if next == 0x4F {
        if begin + 2 >= count {
            return incomplete;
        }
        int code = input[begin + 2];
        match code {
            0x41 => {
                return {consumed: 3, event: namedKey("up")};
            }
            0x42 => {
                return {consumed: 3, event: namedKey("down")};
            }
            0x43 => {
                return {consumed: 3, event: namedKey("right")};
            }
            0x44 => {
                return {consumed: 3, event: namedKey("left")};
            }
            0x48 => {
                return {consumed: 3, event: namedKey("home")};
            }
            0x46 => {
                return {consumed: 3, event: namedKey("end")};
            }
            0x50 => {
                return {consumed: 3, event: namedKey("f1")};
            }
            0x51 => {
                return {consumed: 3, event: namedKey("f2")};
            }
            0x52 => {
                return {consumed: 3, event: namedKey("f3")};
            }
            0x53 => {
                return {consumed: 3, event: namedKey("f4")};
            }
        }
        return {consumed: 3};
    }
    if next == ESC_BYTE || next >= 0x80 {
        return {consumed: 1, event: namedKey("escape")};
    }
    // ESC followed by a key is Alt plus that key
    KeyEvent key = keyForByte(next);
    return {consumed: 2, event: {kind: "key", key: key.key, ctrl: key.ctrl, alt: true, shift: key.shift}};
}

# Decodes the bytes received from a terminal.
#
# + input - the bytes received so far, each 0 to 255
# + giveUp - whether to give up on an incomplete escape sequence: set it after a short silence, so a
#           lone Esc becomes an Escape key
# + awaitingCursor - whether a cursor position request is outstanding: the first `ESC [ row ; col R` is
#                    then taken as the reply (in `report`) and not as a key
# + return - the events found, the reply if one arrived, and the bytes that are not yet a complete event
isolated function decodeInput(int[] input, boolean giveUp, boolean awaitingCursor = false) returns DecodeResult {
    InputEvent[] events = [];
    CursorPosition? report = ();
    boolean waiting = awaitingCursor;
    int count = input.length();
    int i = 0;
    while i < count {
        int code = input[i];
        if code == ESC_BYTE {
            Parsed parsed = parseEscape(input, i, giveUp, waiting);
            if parsed.consumed == 0 {
                break;
            }
            CursorPosition? found = parsed.report;
            if found is CursorPosition {
                report = found;
                waiting = false; // one request, one reply
            }
            InputEvent? event = parsed.event;
            if event is InputEvent {
                events.push(event);
            }
            i += parsed.consumed;
        } else if code < 0x80 {
            events.push(keyForByte(code));
            i += 1;
        } else {
            int length = utf8Length(code);
            if length == 0 {
                i += 1; // not a valid first byte: drop it
            } else if i + length > count {
                if giveUp {
                    i = count;
                }
                break;
            } else {
                string? text = decodeText(input.slice(i, i + length));
                if text is string && text.length() == 1 {
                    events.push({kind: "key", key: <string:Char>text});
                }
                i += length;
            }
        }
    }
    return {events, rest: input.slice(i), report};
}
