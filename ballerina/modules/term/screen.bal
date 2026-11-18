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

import ayesha/termui.text;

// A small virtual screen for the in-memory terminal. It interprets the output a renderer emits:
// printable text with autowrap, CR, LF, backspace, tab, cursor movement (CSI A B C D E F G d H f),
// erase (CSI J K), and scrolling into a scrollback. Styles and modes are accepted and ignored.
// Like a terminal in raw mode, a line feed moves down only; it does not return to column 0.

type ScreenState record {|
    string[][] cells;
    string[] scrollback;
    int row;
    int col;
    int width;
    int height;
    boolean pendingWrap;
|};

isolated function blankRow(int width) returns string[] {
    string[] row = [];
    foreach int _ in 0 ..< width {
        row.push(" ");
    }
    return row;
}

isolated function newScreen(int width, int height) returns ScreenState {
    string[][] cells = [];
    foreach int _ in 0 ..< height {
        cells.push(blankRow(width));
    }
    return {cells, scrollback: [], row: 0, col: 0, width, height, pendingWrap: false};
}

isolated function rowText(string[] cells) returns string {
    string out = "";
    foreach string cell in cells {
        out += cell;
    }
    // trim trailing spaces
    int end = out.length();
    while end > 0 && out.substring(end - 1, end) == " " {
        end -= 1;
    }
    return out.substring(0, end);
}

isolated function lineFeed(ScreenState screen) {
    screen.row += 1;
    if screen.row >= screen.height {
        screen.scrollback.push(rowText(screen.cells[0]));
        _ = screen.cells.shift();
        screen.cells.push(blankRow(screen.width));
        screen.row = screen.height - 1;
    }
}

isolated function putChar(ScreenState screen, string:Char char) {
    int cells = text:displayWidth(char);
    if cells == 0 {
        // a combining mark joins the character before it
        int previous = screen.pendingWrap ? screen.col : screen.col - 1;
        if previous >= 0 {
            screen.cells[screen.row][previous] += char;
        }
        return;
    }
    if screen.pendingWrap || screen.col + cells > screen.width {
        screen.col = 0;
        screen.pendingWrap = false;
        lineFeed(screen);
    }
    screen.cells[screen.row][screen.col] = char;
    if cells == 2 && screen.col + 1 < screen.width {
        screen.cells[screen.row][screen.col + 1] = "";
    }
    screen.col += cells;
    if screen.col >= screen.width {
        screen.col = screen.width - 1;
        screen.pendingWrap = true;
    }
}

isolated function parseParams(string params) returns int[] {
    int[] values = [];
    string cleaned = params.startsWith("?") ? params.substring(1) : params;
    foreach string part in re `;`.split(cleaned) {
        int|error value = int:fromString(part);
        values.push(value is int ? value : 0);
    }
    return values;
}

isolated function param(int[] values, int index, int fallback) returns int {
    if index < values.length() && values[index] > 0 {
        return values[index];
    }
    return fallback;
}

isolated function eraseCells(ScreenState screen, int row, int fromCol, int toCol) {
    foreach int c in fromCol ... toCol {
        screen.cells[row][c] = " ";
    }
}

isolated function handleCsi(ScreenState screen, string params, string:Char command) {
    if params.startsWith("?") {
        return; // private modes (alternate screen, cursor visibility, ...) are ignored
    }
    int[] values = parseParams(params);
    int count = param(values, 0, 1);
    match command {
        "A" => {
            screen.row = int:max(0, screen.row - count);
            screen.pendingWrap = false;
        }
        "B" => {
            screen.row = int:min(screen.height - 1, screen.row + count);
            screen.pendingWrap = false;
        }
        "C" => {
            screen.col = int:min(screen.width - 1, screen.col + count);
            screen.pendingWrap = false;
        }
        "D" => {
            screen.col = int:max(0, screen.col - count);
            screen.pendingWrap = false;
        }
        "E" => {
            screen.row = int:min(screen.height - 1, screen.row + count);
            screen.col = 0;
            screen.pendingWrap = false;
        }
        "F" => {
            screen.row = int:max(0, screen.row - count);
            screen.col = 0;
            screen.pendingWrap = false;
        }
        "G" => {
            screen.col = int:max(0, int:min(screen.width - 1, count - 1));
            screen.pendingWrap = false;
        }
        "d" => {
            screen.row = int:max(0, int:min(screen.height - 1, count - 1));
            screen.pendingWrap = false;
        }
        "H"|"f" => {
            screen.row = int:max(0, int:min(screen.height - 1, param(values, 0, 1) - 1));
            screen.col = int:max(0, int:min(screen.width - 1, param(values, 1, 1) - 1));
            screen.pendingWrap = false;
        }
        "J" => {
            int mode = values.length() > 0 ? values[0] : 0;
            if mode == 0 {
                eraseCells(screen, screen.row, screen.col, screen.width - 1);
                foreach int r in screen.row + 1 ..< screen.height {
                    eraseCells(screen, r, 0, screen.width - 1);
                }
            } else if mode == 1 {
                eraseCells(screen, screen.row, 0, screen.col);
                foreach int r in 0 ..< screen.row {
                    eraseCells(screen, r, 0, screen.width - 1);
                }
            } else if mode == 2 {
                foreach int r in 0 ..< screen.height {
                    eraseCells(screen, r, 0, screen.width - 1);
                }
            } else if mode == 3 {
                screen.scrollback = [];
            }
        }
        "K" => {
            int mode = values.length() > 0 ? values[0] : 0;
            if mode == 0 {
                eraseCells(screen, screen.row, screen.col, screen.width - 1);
            } else if mode == 1 {
                eraseCells(screen, screen.row, 0, screen.col);
            } else if mode == 2 {
                eraseCells(screen, screen.row, 0, screen.width - 1);
            }
        }
        _ => {
            // styles (m), modes (h, l), and cursor save/restore (s, u) do not change the text
        }
    }
}

// Applies output to the screen the way a terminal in raw mode would show it.
isolated function applyOutput(ScreenState screen, string data) {
    string mode = "text";
    string params = "";
    foreach string:Char char in data {
        int code = char.toCodePointInt();
        if mode == "esc" {
            if char == "[" {
                mode = "csi";
                params = "";
            } else if char == "]" {
                mode = "osc";
            } else {
                mode = "text";
            }
        } else if mode == "csi" {
            if code >= 0x20 && code <= 0x3F {
                params += char;
            } else {
                if code >= 0x40 && code <= 0x7E {
                    handleCsi(screen, params, char);
                }
                mode = "text";
            }
        } else if mode == "osc" {
            if code == 0x07 {
                mode = "text";
            } else if code == 0x1B {
                mode = "oscEnd";
            }
        } else if mode == "oscEnd" {
            mode = "text";
        } else if code == 0x1B {
            mode = "esc";
        } else if code == 0x0D {
            screen.col = 0;
            screen.pendingWrap = false;
        } else if code == 0x0A {
            lineFeed(screen);
        } else if code == 0x08 {
            screen.col = int:max(0, screen.col - 1);
            screen.pendingWrap = false;
        } else if code == 0x09 {
            screen.col = int:min(screen.width - 1, (screen.col / 8 + 1) * 8);
            screen.pendingWrap = false;
        } else if code >= 0x20 {
            putChar(screen, char);
        }
    }
}

isolated function resizeScreen(ScreenState screen, int width, int height) {
    while screen.cells.length() > height {
        // rows that no longer fit move into the scrollback, as a terminal would show them
        screen.scrollback.push(rowText(screen.cells[0]));
        _ = screen.cells.shift();
        screen.row = int:max(0, screen.row - 1);
    }
    while screen.cells.length() < height {
        screen.cells.push(blankRow(width));
    }
    foreach int r in 0 ..< height {
        string[] cells = screen.cells[r];
        while cells.length() > width {
            _ = cells.pop();
        }
        while cells.length() < width {
            cells.push(" ");
        }
    }
    screen.width = width;
    screen.height = height;
    screen.row = int:min(screen.row, height - 1);
    screen.col = int:min(screen.col, width - 1);
    screen.pendingWrap = false;
}
