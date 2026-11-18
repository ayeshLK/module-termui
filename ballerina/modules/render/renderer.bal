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

# Something the application draws on: a live region that is redrawn, and finished output that is
# committed once. `InlineRenderer` is the interactive one; `PlainRenderer` is for output that is not
# a terminal.
public type Renderer object {
    # Replaces the live region with these lines.
    #
    # + lines - the lines of the live region, one per row
    # + return - an error when the terminal cannot be written
    public function draw(txt:Span[][] lines) returns error?;

    # Writes finished paragraphs above the live region. Each paragraph is one logical line, so the
    # terminal wraps it and can re-wrap it when the window is resized.
    #
    # + paragraphs - the paragraphs
    # + return - an error when the terminal cannot be written
    public function commitProse(txt:Span[][] paragraphs) returns error?;

    # Writes a finished block above the live region, wrapped to the width at this moment because its
    # layout (a table, a box, a diff) cannot be re-wrapped later.
    #
    # + lines - the lines of the block
    # + return - an error when the terminal cannot be written
    public function commitBlock(txt:Span[][] lines) returns error?;

    # Tells the renderer that the window changed size. Draw the live region again afterwards.
    #
    # + width - the new number of columns
    # + height - the new number of rows
    # + return - an error when the terminal cannot be written
    public function resize(int width, int height) returns error?;

    # Finishes: leaves the output in place and the cursor on a fresh line.
    #
    # + return - an error when the terminal cannot be written
    public function close() returns error?;
};

isolated function ceilDiv(int value, int divisor) returns int {
    return (value + divisor - 1) / divisor;
}

isolated function toTerminalText(string value) returns string {
    return re `\n`.replaceAll(value, "\r\n"); // raw mode: a line feed alone does not return to column 0
}

// What the inline region looked like when the screen was switched away, so it can be put back.
type InlineState record {|
    Buffer? previous;
    int cursorRow;
|};

# Draws a live region at the bottom of the terminal without taking over the screen, and writes
# finished output above it into the normal scrollback.
#
# The region starts on the cursor's current row, which must be at column 0 (start of a line). Each
# `draw` writes only what changed since the last one, using relative cursor movement, and leaves the
# cursor at column 0 of the region's last row. Committed output is never redrawn. The region is at most
# as tall as the terminal.
public class InlineRenderer {
    *Renderer;

    private final term:Terminal terminal;
    private int width;
    private int height;
    private final boolean colors;
    private final boolean reflow;
    private Buffer? previous = ();
    private int cursorRow = 0;
    private boolean fullScreen = false;
    private InlineState? savedInline = ();

    # + terminal - the terminal to draw on
    # + width - the number of columns
    # + height - the number of rows
    # + colors - whether to write color sequences
    # + reflow - whether the terminal re-wraps text that was wrapped automatically when it is resized
    #            (most do); it decides how many rows the live region occupies after a resize
    public function init(term:Terminal terminal, int width, int height, boolean colors = true, boolean reflow = true) {
        self.terminal = terminal;
        self.width = width;
        self.height = height;
        self.colors = colors;
        self.reflow = reflow;
    }

    # The live region as it was last drawn, for tests and tools that want to look at it.
    #
    # + return - the buffer, or `()` before the first draw
    public function frame() returns Buffer? {
        return self.previous;
    }

    public function draw(txt:Span[][] lines) returns error? {
        string out = self.fullScreen ? self.drawFullScreen(lines) : self.drawInline(lines);
        if out != "" {
            check self.terminal.write(out);
        }
    }

    private function drawInline(txt:Span[][] lines) returns string {
        txt:Span[][] visible = lines.length() > self.height ? lines.slice(lines.length() - self.height) : lines;
        Buffer next = bufferFromLines(visible, self.width);
        Buffer? previousBuffer = self.previous;
        int previousHeight = previousBuffer is Buffer ? previousBuffer.height : 0;
        string out = "";
        int cursor = self.cursorRow;
        if previousBuffer is () || previousHeight == 0 {
            foreach int row in 0 ..< next.height {
                out += (row > 0 ? "\r\n" : "") + rowUpdate((), next.cells[row], self.colors);
            }
            cursor = next.height > 0 ? next.height - 1 : 0;
        } else {
            foreach int row in 0 ..< int:min(previousHeight, next.height) {
                string update = rowUpdate(previousBuffer.cells[row], next.cells[row], self.colors);
                if update != "" {
                    out += moveRows(cursor, row) + update;
                    cursor = row;
                }
            }
            if next.height > previousHeight {
                out += moveRows(cursor, previousHeight - 1);
                cursor = previousHeight - 1;
                foreach int row in previousHeight ..< next.height {
                    out += "\r\n" + rowUpdate((), next.cells[row], self.colors);
                    cursor = row;
                }
            } else if next.height < previousHeight {
                out += moveRows(cursor, next.height) + toColumn(0) + ERASE_BELOW;
                cursor = next.height;
                if next.height > 0 {
                    out += moveRows(cursor, next.height - 1);
                    cursor = next.height - 1;
                }
            }
        }
        if out != "" {
            out += toColumn(0);
        }
        self.previous = next;
        self.cursorRow = cursor;
        return out;
    }

    private function drawFullScreen(txt:Span[][] lines) returns string {
        txt:Span[][] padded = [];
        foreach int row in 0 ..< self.height {
            padded.push(row < lines.length() ? lines[row] : []);
        }
        Buffer next = bufferFromLines(padded, self.width);
        Buffer? previousBuffer = self.previous;
        string out = "";
        foreach int row in 0 ..< next.height {
            Cell[]? before = previousBuffer is Buffer ? previousBuffer.cells[row] : ();
            string update = rowUpdate(before, next.cells[row], self.colors);
            if update != "" {
                out += string `${ESC}[${row + 1};1H` + update;
            }
        }
        self.previous = next;
        return out;
    }

    public function commitProse(txt:Span[][] paragraphs) returns error? {
        string[] rendered = [];
        foreach txt:Span[] paragraph in paragraphs {
            rendered.push(toTerminalText(txt:toAnsi(paragraph, self.colors)));
        }
        check self.writeAbove(rendered);
    }

    public function commitBlock(txt:Span[][] lines) returns error? {
        string[] rendered = [];
        foreach txt:Span[] line in lines {
            foreach txt:Span[] row in txt:wrap(line, self.width) {
                rendered.push(txt:toAnsi(row, self.colors));
            }
        }
        check self.writeAbove(rendered);
    }

    // Writes lines above the live region in one write: clear the region, write the lines (which scroll
    // into the terminal's history), and draw the region again below them.
    private function writeAbove(string[] rendered) returns error? {
        if self.fullScreen {
            return error("commit is not available in full-screen mode");
        }
        Buffer? region = self.previous;
        int regionHeight = region is Buffer ? region.height : 0;
        string out = "";
        if regionHeight > 0 {
            out += moveRows(self.cursorRow, 0) + toColumn(0) + ERASE_BELOW;
        }
        foreach string line in rendered {
            out += line + "\r\n";
        }
        if region is Buffer && regionHeight > 0 {
            foreach int row in 0 ..< regionHeight {
                out += (row > 0 ? "\r\n" : "") + rowUpdate((), region.cells[row], self.colors);
            }
            out += toColumn(0);
            self.cursorRow = regionHeight - 1;
        } else {
            self.cursorRow = 0;
        }
        if out != "" {
            check self.terminal.write(out);
        }
    }

    public function resize(int width, int height) returns error? {
        string out = "";
        if self.fullScreen {
            out = ESC + "[2J" + ESC + "[H";
        } else {
            Buffer? region = self.previous;
            if region is Buffer && region.height > 0 {
                // After the resize the terminal may have re-wrapped the old rows, so count how many rows
                // the region occupies now: each old row takes ceil(its content width / new width) rows.
                int up = self.cursorRow;
                if self.reflow && width != self.width {
                    up = 0;
                    foreach int row in 0 ..< self.cursorRow {
                        up += int:max(1, ceilDiv(contentWidth(region.cells[row]), width));
                    }
                }
                out = (up > 0 ? string `${ESC}[${up}A` : "") + toColumn(0) + ERASE_BELOW;
            }
        }
        self.width = width;
        self.height = height;
        self.previous = ();
        self.cursorRow = 0;
        if out != "" {
            check self.terminal.write(out);
        }
    }

    # Switches to the alternate screen, for an interface that fills the terminal. Committing is not
    # available there. The inline region is remembered and comes back with `leaveFullScreen`.
    #
    # + return - an error when the terminal cannot be written
    public function enterFullScreen() returns error? {
        if self.fullScreen {
            return;
        }
        self.savedInline = {previous: self.previous, cursorRow: self.cursorRow};
        self.fullScreen = true;
        self.previous = ();
        check self.terminal.write(ESC + "[?1049h" + ESC + "[2J" + ESC + "[H");
    }

    # Switches back to the normal screen, which shows what it showed before.
    #
    # + return - an error when the terminal cannot be written
    public function leaveFullScreen() returns error? {
        if !self.fullScreen {
            return;
        }
        self.fullScreen = false;
        InlineState? saved = self.savedInline;
        self.previous = saved is InlineState ? saved.previous : ();
        self.cursorRow = saved is InlineState ? saved.cursorRow : 0;
        self.savedInline = ();
        check self.terminal.write(ESC + "[?1049l");
    }

    public function close() returns error? {
        if self.fullScreen {
            check self.leaveFullScreen();
        }
        Buffer? region = self.previous;
        if region is Buffer && region.height > 0 {
            check self.terminal.write("\r\n");
        }
        self.previous = ();
        self.cursorRow = 0;
    }
}

isolated function stripEscapes(string value) returns string {
    return re `\u{1b}\[[0-9;?]*[ -/]*[@-~]`.replaceAll(value, "");
}

# Writes plain text for output that is not an interactive terminal: committed output as lines without
# styling or cursor control, and the live region only once, as its final state when the renderer is
# closed, so a spinner is not repeated line after line.
public class PlainRenderer {
    *Renderer;

    private final term:Terminal terminal;
    private int width;
    private txt:Span[][] latest = [];

    # + terminal - where to write
    # + width - the width used to wrap committed blocks
    public function init(term:Terminal terminal, int width = 80) {
        self.terminal = terminal;
        self.width = width;
    }

    public function draw(txt:Span[][] lines) returns error? {
        self.latest = lines;
    }

    public function commitProse(txt:Span[][] paragraphs) returns error? {
        string out = "";
        foreach txt:Span[] paragraph in paragraphs {
            out += stripEscapes(txt:plainText(paragraph)) + "\n";
        }
        if out != "" {
            check self.terminal.write(out);
        }
    }

    public function commitBlock(txt:Span[][] lines) returns error? {
        string out = "";
        foreach txt:Span[] line in lines {
            foreach txt:Span[] row in txt:wrap(line, self.width) {
                out += stripEscapes(txt:plainText(row)) + "\n";
            }
        }
        if out != "" {
            check self.terminal.write(out);
        }
    }

    public function resize(int width, int height) returns error? {
        self.width = width;
    }

    public function close() returns error? {
        txt:Span[][] last = self.latest;
        self.latest = [];
        check self.commitProse(last);
    }
}
