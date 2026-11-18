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

import ayesha/termui.text as txt;

const string ESC = "\u{1b}";
const string RESET = ESC + "[0m";
const string ERASE_TO_END_OF_LINE = ESC + "[K";
const string ERASE_BELOW = ESC + "[J";

isolated function cellsEqual(Cell a, Cell b) returns boolean {
    return a.text == b.text && a.style == b.style;
}

isolated function toColumn(int column) returns string {
    return string `${ESC}[${column + 1}G`;
}

// Moves the cursor between rows of the live region.
isolated function moveRows(int fromRow, int toRow) returns string {
    if toRow > fromRow {
        return string `${ESC}[${toRow - fromRow}B`;
    }
    if toRow < fromRow {
        return string `${ESC}[${fromRow - toRow}A`;
    }
    return "";
}

isolated function styledText(Cell[] cells, int begin, int end, boolean colors) returns string {
    string out = "";
    int i = begin;
    while i < end {
        txt:Style style = cells[i].style;
        string segment = "";
        while i < end && cells[i].style == style {
            segment += cells[i].text;
            i += 1;
        }
        string sequence = txt:sgr(style, colors);
        out += sequence == "" ? segment : sequence + segment + RESET;
    }
    return out;
}

// What to write to turn one row of the screen into `next`: for each run of changed cells, a move to
// its column and the new text, then an erase if the old row had content further right. `previous` is
// the row as it is on screen, or `()` when the row is empty. The cursor is assumed to be on the row.
isolated function rowUpdate(Cell[]? previous, Cell[] next, boolean colors) returns string {
    int content = contentWidth(next);
    string out = "";
    int col = 0;
    while col < content {
        if previous is Cell[] && cellsEqual(previous[col], next[col]) {
            col += 1;
            continue;
        }
        int begin = col;
        while col < content && (previous is () || !cellsEqual(previous[col], next[col])) {
            col += 1;
        }
        while begin > 0 && next[begin].text == "" {
            begin -= 1; // never start in the middle of a wide character
        }
        while col < content && next[col].text == "" {
            col += 1;
        }
        out += toColumn(begin) + styledText(next, begin, col, colors);
    }
    if previous is Cell[] && contentWidth(previous) > content {
        out += toColumn(content) + ERASE_TO_END_OF_LINE;
    }
    return out;
}
