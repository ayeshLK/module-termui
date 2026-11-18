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

# One cell of the screen.
#
# + text - the character shown (with any combining marks), `" "` for an empty cell, or `""` for the
#          second half of a wide character
# + style - the style of the cell
public type Cell record {|
    string text;
    txt:Style style;
|};

# A grid of cells: what the live region looks like.
#
# + width - the number of columns
# + height - the number of rows
# + cells - the rows of cells, `height` rows of `width` cells each
public type Buffer record {|
    int width;
    int height;
    Cell[][] cells;
|};

isolated function blankCell() returns Cell {
    return {text: " ", style: {}};
}

# Creates a buffer of empty cells.
#
# + width - the number of columns
# + height - the number of rows
# + return - the buffer
public isolated function newBuffer(int width, int height) returns Buffer {
    Cell[][] rows = [];
    foreach int _ in 0 ..< height {
        Cell[] row = [];
        foreach int _ in 0 ..< width {
            row.push(blankCell());
        }
        rows.push(row);
    }
    return {width, height, cells: rows};
}

isolated function writeSpans(Buffer buffer, int row, txt:Span[] spans) {
    int col = 0;
    foreach txt:Span span in spans {
        foreach string:Char char in span.text {
            int code = char.toCodePointInt();
            if code < 0x20 || code == 0x7F {
                continue;
            }
            int cells = txt:displayWidth(char);
            if cells == 0 {
                if col > 0 {
                    buffer.cells[row][col - 1].text += char; // a combining mark joins the character before it
                }
                continue;
            }
            if col + cells > buffer.width {
                return; // the line is cut at the right edge
            }
            buffer.cells[row][col] = {text: char, style: span.style};
            if cells == 2 {
                buffer.cells[row][col + 1] = {text: "", style: span.style};
            }
            col += cells;
        }
    }
}

# Lays out lines of styled text in a buffer, one line per row. Lines wider than the buffer are cut off;
# wrap them first with the `text` module to avoid that.
#
# + lines - the lines
# + width - the number of columns
# + return - a buffer with one row per line
public isolated function bufferFromLines(txt:Span[][] lines, int width) returns Buffer {
    Buffer buffer = newBuffer(width, lines.length());
    foreach int row in 0 ..< lines.length() {
        writeSpans(buffer, row, lines[row]);
    }
    return buffer;
}

isolated function isDefaultStyle(txt:Style style) returns boolean {
    return !style.bold && !style.dim && !style.italic && !style.underline && !style.reverse
        && style?.fg is () && style?.bg is ();
}

isolated function isBlank(Cell cell) returns boolean {
    return cell.text == " " && isDefaultStyle(cell.style);
}

// The number of columns up to and including the last cell that is not blank.
isolated function contentWidth(Cell[] row) returns int {
    int end = row.length();
    while end > 0 && isBlank(row[end - 1]) {
        end -= 1;
    }
    return end;
}

# The text of each row of a buffer, with trailing spaces trimmed, so a test can compare what is shown.
#
# + buffer - the buffer
# + return - one string per row
public isolated function bufferLines(Buffer buffer) returns string[] {
    string[] lines = [];
    foreach Cell[] row in buffer.cells {
        string line = "";
        foreach Cell cell in row.slice(0, contentWidth(row)) {
            line += cell.text;
        }
        lines.push(line);
    }
    return lines;
}

# The cell at a position.
#
# + buffer - the buffer
# + row - the row, counted from zero
# + column - the column, counted from zero
# + return - the cell, including its style
public isolated function cellAt(Buffer buffer, int row, int column) returns Cell {
    return buffer.cells[row][column];
}
