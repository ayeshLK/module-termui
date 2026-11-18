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

// Inclusive code point ranges, sorted ascending and non-overlapping, searched with a binary search.
// They are abbreviated tables for the scripts terminals meet most: combining marks and format
// characters (zero columns), and East Asian wide, fullwidth, and emoji characters (two columns).

final int[][] & readonly ZERO_WIDTH_RANGES = [
    [0x0300, 0x036F], [0x0483, 0x0489], [0x0591, 0x05BD], [0x05BF, 0x05BF], [0x05C1, 0x05C2],
    [0x05C4, 0x05C5], [0x05C7, 0x05C7], [0x0610, 0x061A], [0x064B, 0x065F], [0x0670, 0x0670],
    [0x06D6, 0x06DC], [0x06DF, 0x06E4], [0x06E7, 0x06E8], [0x06EA, 0x06ED], [0x0711, 0x0711],
    [0x0730, 0x074A], [0x07A6, 0x07B0], [0x0900, 0x0902], [0x093A, 0x093A], [0x093C, 0x093C],
    [0x0941, 0x0948], [0x094D, 0x094D], [0x0951, 0x0957], [0x0E31, 0x0E31], [0x0E34, 0x0E3A],
    [0x0E47, 0x0E4E], [0x1AB0, 0x1AFF], [0x1DC0, 0x1DFF], [0x200B, 0x200F], [0x202A, 0x202E],
    [0x2060, 0x2064], [0x20D0, 0x20FF], [0xFE00, 0xFE0F], [0xFE20, 0xFE2F], [0xFEFF, 0xFEFF],
    [0xE0100, 0xE01EF]
];

final int[][] & readonly WIDE_RANGES = [
    [0x1100, 0x115F], [0x231A, 0x231B], [0x2329, 0x232A], [0x23E9, 0x23EC], [0x23F0, 0x23F0],
    [0x23F3, 0x23F3], [0x25FD, 0x25FE], [0x2614, 0x2615], [0x2648, 0x2653], [0x267F, 0x267F],
    [0x2693, 0x2693], [0x26A1, 0x26A1], [0x26AA, 0x26AB], [0x26BD, 0x26BE], [0x26C4, 0x26C5],
    [0x26CE, 0x26CE], [0x26D4, 0x26D4], [0x26EA, 0x26EA], [0x26F2, 0x26F3], [0x26F5, 0x26F5],
    [0x26FA, 0x26FA], [0x26FD, 0x26FD], [0x2705, 0x2705], [0x270A, 0x270B], [0x2728, 0x2728],
    [0x274C, 0x274C], [0x274E, 0x274E], [0x2753, 0x2755], [0x2757, 0x2757], [0x2795, 0x2797],
    [0x27B0, 0x27B0], [0x27BF, 0x27BF], [0x2B1B, 0x2B1C], [0x2B50, 0x2B50], [0x2B55, 0x2B55],
    [0x2E80, 0x303E], [0x3041, 0x33FF], [0x3400, 0x4DBF], [0x4E00, 0x9FFF], [0xA000, 0xA4CF],
    [0xA960, 0xA97F], [0xAC00, 0xD7A3], [0xF900, 0xFAFF], [0xFE10, 0xFE19], [0xFE30, 0xFE6F],
    [0xFF01, 0xFF60], [0xFFE0, 0xFFE6], [0x1F004, 0x1F004], [0x1F0CF, 0x1F0CF], [0x1F18E, 0x1F18E],
    [0x1F191, 0x1F19A], [0x1F200, 0x1F320], [0x1F32D, 0x1F335], [0x1F337, 0x1F37C],
    [0x1F37E, 0x1F393], [0x1F3A0, 0x1F3CA], [0x1F3CF, 0x1F3D3], [0x1F3E0, 0x1F3F0],
    [0x1F3F4, 0x1F3F4], [0x1F3F8, 0x1F43E], [0x1F440, 0x1F440], [0x1F442, 0x1F4FC],
    [0x1F4FF, 0x1F53D], [0x1F54B, 0x1F54E], [0x1F550, 0x1F567], [0x1F57A, 0x1F57A],
    [0x1F595, 0x1F596], [0x1F5A4, 0x1F5A4], [0x1F5FB, 0x1F64F], [0x1F680, 0x1F6C5],
    [0x1F6CC, 0x1F6CC], [0x1F6D0, 0x1F6D2], [0x1F6D5, 0x1F6D7], [0x1F6EB, 0x1F6EC],
    [0x1F6F4, 0x1F6FC], [0x1F7E0, 0x1F7EB], [0x1F90C, 0x1F93A], [0x1F93C, 0x1F945],
    [0x1F947, 0x1F9FF], [0x1FA70, 0x1FAFF], [0x20000, 0x2FFFD], [0x30000, 0x3FFFD]
];

const int ZERO_WIDTH_JOINER = 0x200D;

isolated function inRanges(int codePoint, int[][] ranges) returns boolean {
    int low = 0;
    int high = ranges.length() - 1;
    while low <= high {
        int middle = (low + high) / 2;
        int[] range = ranges[middle];
        if codePoint < range[0] {
            high = middle - 1;
        } else if codePoint > range[1] {
            low = middle + 1;
        } else {
            return true;
        }
    }
    return false;
}

// The number of columns one code point takes, ignoring joining: control characters and combining
// marks take none, wide characters take two, everything else takes one.
isolated function codePointWidth(int codePoint) returns int {
    if codePoint < 0x20 || (codePoint >= 0x7F && codePoint < 0xA0) {
        return 0;
    }
    if inRanges(codePoint, ZERO_WIDTH_RANGES) {
        return 0;
    }
    if inRanges(codePoint, WIDE_RANGES) {
        return 2;
    }
    return 1;
}

// The width of one code point and whether the next one is joined to it (after a zero-width joiner,
// the following code point continues the same grapheme and adds no columns).
isolated function cellWidth(int codePoint, boolean joined) returns [int, boolean] {
    if codePoint == ZERO_WIDTH_JOINER {
        return [0, true];
    }
    if joined {
        return [0, false];
    }
    return [codePointWidth(codePoint), false];
}

isolated function toChars(string text) returns string:Char[] {
    string:Char[] chars = [];
    foreach string:Char char in text {
        chars.push(char);
    }
    return chars;
}

// The number of characters in the ANSI escape sequence that starts at index `i`, or 0 when none does.
// Handles CSI (ESC [ ... final byte), OSC (ESC ] ... BEL or ESC \), and two-character escapes.
isolated function escapeLength(string:Char[] chars, int i) returns int {
    int count = chars.length();
    if chars[i].toCodePointInt() != 0x1B {
        return 0;
    }
    if i + 1 >= count {
        return 1;
    }
    int next = chars[i + 1].toCodePointInt();
    if next == 0x5B {
        int j = i + 2;
        while j < count {
            int code = chars[j].toCodePointInt();
            if code >= 0x40 && code <= 0x7E {
                return j - i + 1;
            }
            if code < 0x20 || code > 0x3F {
                return j - i;
            }
            j += 1;
        }
        return count - i;
    }
    if next == 0x5D {
        int j = i + 2;
        while j < count {
            int code = chars[j].toCodePointInt();
            if code == 0x07 {
                return j - i + 1;
            }
            if code == 0x1B && j + 1 < count && chars[j + 1].toCodePointInt() == 0x5C {
                return j - i + 2;
            }
            j += 1;
        }
        return count - i;
    }
    return 2;
}

# Measures how many terminal columns a string takes when displayed.
#
# Wide characters (CJK, emoji) count two columns, combining marks and zero-width characters count
# none, ANSI escape sequences count none, and a zero-width joiner merges the following character into
# the previous one. Tables are abbreviated; unlisted code points count one column.
#
# + text - the string to measure
# + return - the number of columns
public isolated function displayWidth(string text) returns int {
    string:Char[] chars = toChars(text);
    int width = 0;
    boolean joined = false;
    int i = 0;
    while i < chars.length() {
        int skip = escapeLength(chars, i);
        if skip > 0 {
            i += skip;
            continue;
        }
        [int, boolean] [cells, nextJoined] = cellWidth(chars[i].toCodePointInt(), joined);
        width += cells;
        joined = nextJoined;
        i += 1;
    }
    return width;
}
