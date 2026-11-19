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
#
# The five methods below are the whole contract: an implementation of only those works with the
# runtime. Further abilities are separate capability types that a renderer may also implement, so a
# new ability never adds a required method here.
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
    boolean anchored;
    int gap;
|};

// How to put a region of `regionHeight` rows on the last rows of a `height`-row screen when the first free
// row (the row after the output) is `row`: move to the last row, scroll by exactly the rows that are
// missing (none when there is room), and go up to the region's top. Also returns the number of blank rows
// that are left between the output and the region.
isolated function anchorSequence(int row, int regionHeight, int height) returns [string, int] {
    int scroll = int:max(0, row + regionHeight - height);
    string out = string `${ESC}[${height}B`;
    foreach int _ in 0 ..< scroll {
        out += "\n";
    }
    if regionHeight > 1 {
        out += string `${ESC}[${regionHeight - 1}A`;
    }
    return [out, int:max(0, height - regionHeight - row)];
}

// The number of rows a terminal of this width uses for the text: each line wraps the way the in-memory
// terminal wraps (a wide character that does not fit moves to the next row).
isolated function rowsOccupied(string text, int width) returns int {
    int total = 0;
    foreach string segment in re `\r\n`.split(stripEscapes(text)) {
        int rows = 1;
        int col = 0;
        boolean pending = false;
        foreach string:Char char in segment {
            if char == "\t" {
                col = int:min((col / 8 + 1) * 8, width - 1);
                pending = false;
                continue;
            }
            int cells = txt:displayWidth(char);
            if cells == 0 {
                continue;
            }
            if pending || col + cells > width {
                rows += 1;
                col = 0;
                pending = false;
            }
            col += cells;
            if col >= width {
                col = width - 1;
                pending = true;
            }
        }
        total += rows;
    }
    return total;
}

// Text outside ASCII may be drawn with a different width by some terminals, so its row count is not trusted.
isolated function hasNonAscii(string text) returns boolean {
    foreach string:Char char in text {
        if char.toCodePointInt() > 0x7F {
            return true;
        }
    }
    return false;
}

# Draws a live region at the bottom of the terminal without taking over the screen, and writes
# finished output above it into the normal scrollback.
#
# The region starts on the cursor's current row, which must be at column 0 (start of a line). Each
# `draw` writes only what changed since the last one, using relative cursor movement, and leaves the
# cursor at column 0 of the region's last row. Committed output is never redrawn. The region is at most
# as tall as the terminal.
#
# With `anchorBottom` the region is kept on the last rows of the terminal instead, if the terminal reports
# where its cursor is (see `term:CursorReporter`): the blank rows between the existing output and the region
# are used for committed output and for the region's growth before the screen scrolls, so nothing that was
# on screen moves until the conversation fills it, and no blank row ever reaches the scrollback. Without a
# cursor report it behaves exactly as without the option.
public class InlineRenderer {
    *Renderer;

    private final term:Terminal terminal;
    private int width;
    private int height;
    private final boolean colors;
    private final boolean reflow;
    private final boolean anchorBottom;
    // when anchored: the region is on the last rows, `gap` blank rows lie between the output and the region,
    // and the cursor rests on the last row
    private boolean anchored = false;
    private int gap = 0;
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
    # + anchorBottom - whether to keep the live region on the last rows of the terminal, using the blank
    #                  rows above it before anything scrolls; needs a terminal that reports its cursor
    public function init(term:Terminal terminal, int width, int height, boolean colors = true, boolean reflow = true,
            boolean anchorBottom = false) {
        self.terminal = terminal;
        self.width = width;
        self.height = height;
        self.colors = colors;
        self.reflow = reflow;
        self.anchorBottom = anchorBottom;
    }

    // The row the cursor is on, counted from zero, or `()` when the terminal does not say.
    private function cursorRowFromTerminal() returns int? {
        term:Terminal current = self.terminal;
        if current is term:CursorReporter {
            term:CursorPosition|error? position = current.queryCursor();
            if position is term:CursorPosition {
                return position.row;
            }
        }
        return ();
    }

    # The live region as it was last drawn, for tests and tools that want to look at it.
    #
    # + return - the buffer, or `()` before the first draw
    public function frame() returns Buffer? {
        return self.previous;
    }

    # Draws the live region (see `Renderer.draw`).
    #
    # + lines - the lines of the live region, one per row
    # + return - an error when the terminal cannot be written
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
        if self.anchored && previousBuffer is Buffer && previousHeight > 0 {
            return self.drawAnchored(previousBuffer, next);
        }
        string out = "";
        int cursor = self.cursorRow;
        if previousBuffer is () || previousHeight == 0 {
            self.anchored = false;
            self.gap = 0;
            if self.anchorBottom && next.height > 0 {
                int? row = self.cursorRowFromTerminal();
                if row is int {
                    [string, int] [sequence, blankRows] = anchorSequence(row, next.height, self.height);
                    out += sequence;
                    self.anchored = true;
                    self.gap = blankRows;
                }
            }
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

    // Draws a region that is anchored to the last rows. Rows are compared aligned at the bottom, so a
    // region that grows or shrinks keeps its last rows where they are, and what changes goes through the
    // blank rows above the region before anything scrolls.
    private function drawAnchored(Buffer before, Buffer next) returns string {
        int h = self.height;
        int p = before.height;
        int n = next.height;
        string out = "";
        int cur = h - 1; // the cursor rests on the last row
        if n == p {
            foreach int row in 0 ..< n {
                string update = rowUpdate(before.cells[row], next.cells[row], self.colors);
                if update != "" {
                    out += moveRows(cur, h - p + row) + update;
                    cur = h - p + row;
                }
            }
        } else if n > p {
            int d = n - p;
            if d <= self.gap {
                // the new rows go into the blank rows above the region, and the old rows stay put
                foreach int j in 0 ..< d {
                    string update = rowUpdate((), next.cells[j], self.colors);
                    if update != "" {
                        out += moveRows(cur, h - n + j) + update;
                        cur = h - n + j;
                    }
                }
                foreach int i in 0 ..< p {
                    string update = rowUpdate(before.cells[i], next.cells[i + d], self.colors);
                    if update != "" {
                        out += moveRows(cur, h - p + i) + update;
                        cur = h - p + i;
                    }
                }
                self.gap -= d;
            } else {
                // not enough blank rows: clear the region, scroll for the shortfall only, and write it whole
                out += moveRows(cur, h - p) + toColumn(0) + ERASE_BELOW;
                [string, int] [sequence, blankRows] = anchorSequence(h - p - self.gap, n, h);
                out += sequence;
                foreach int row in 0 ..< n {
                    out += (row > 0 ? "\r\n" : "") + rowUpdate((), next.cells[row], self.colors);
                }
                cur = h - 1;
                self.gap = blankRows;
            }
        } else {
            // the vacated top rows are erased and become blank rows; the last rows do not move
            int d = p - n;
            foreach int i in 0 ..< d {
                out += moveRows(cur, h - p + i) + toColumn(0) + ERASE_TO_END_OF_LINE;
                cur = h - p + i;
            }
            foreach int j in 0 ..< n {
                string update = rowUpdate(before.cells[j + d], next.cells[j], self.colors);
                if update != "" {
                    out += moveRows(cur, h - n + j) + update;
                    cur = h - n + j;
                }
            }
            if n == 0 {
                // nothing left on screen: wait at the end of the output, and anchor again at the next draw
                int outputEnd = h - p - self.gap;
                out += moveRows(cur, outputEnd);
                cur = outputEnd;
                self.anchored = false;
                self.gap = 0;
            } else {
                self.gap += d;
            }
        }
        if self.anchored {
            out += moveRows(cur, h - 1);
        }
        if out != "" {
            out += toColumn(0);
        }
        self.previous = next;
        self.cursorRow = self.anchored ? n - 1 : 0;
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

    # Commits paragraphs above the live region (see `Renderer.commitProse`).
    #
    # + paragraphs - the paragraphs
    # + return - an error when the terminal cannot be written
    public function commitProse(txt:Span[][] paragraphs) returns error? {
        string[] rendered = [];
        foreach txt:Span[] paragraph in paragraphs {
            rendered.push(toTerminalText(txt:toAnsi(paragraph, self.colors)));
        }
        check self.writeAbove(rendered);
    }

    # Commits a block above the live region (see `Renderer.commitBlock`).
    #
    # + lines - the lines of the block
    # + return - an error when the terminal cannot be written
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
        if self.anchored && region is Buffer && regionHeight > 0 {
            return self.writeAboveAnchored(rendered, region);
        }
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

    // The anchored form of writeAbove: the lines go into the blank rows above the region, directly below the
    // existing output, and the region is not touched. Lines that do not fit (or whose width is not
    // certain) are written from the end of the output over the region, and the region is anchored again below.
    private function writeAboveAnchored(string[] rendered, Buffer region) returns error? {
        if rendered.length() == 0 {
            return;
        }
        int h = self.height;
        int m = region.height;
        int outputEnd = h - m - self.gap;
        int needed = 0;
        boolean uncertain = false;
        string text = "";
        foreach string line in rendered {
            needed += rowsOccupied(line, self.width);
            uncertain = uncertain || hasNonAscii(line);
            text += line + "\r\n";
        }
        if needed <= self.gap && !uncertain {
            check self.terminal.write(moveRows(h - 1, outputEnd) + toColumn(0) + text +
                    moveRows(outputEnd + needed, h - 1) + toColumn(0));
            self.gap -= needed;
            return;
        }
        string out = moveRows(h - 1, outputEnd) + toColumn(0) + ERASE_BELOW + text;
        int row = int:min(outputEnd + needed, h - 1);
        if uncertain {
            // measure instead of counting: a terminal may draw some characters wider or narrower than expected
            check self.terminal.write(out);
            out = "";
            int? measured = self.cursorRowFromTerminal();
            if measured is int {
                row = measured;
            }
        }
        [string, int] [sequence, blankRows] = anchorSequence(row, m, h);
        out += sequence;
        foreach int index in 0 ..< m {
            out += (index > 0 ? "\r\n" : "") + rowUpdate((), region.cells[index], self.colors);
        }
        out += toColumn(0);
        self.gap = blankRows;
        self.cursorRow = m - 1;
        check self.terminal.write(out);
    }

    # Handles a change of window size (see `Renderer.resize`).
    #
    # + width - the new number of columns
    # + height - the new number of rows
    # + return - an error when the terminal cannot be written
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
                if self.anchored {
                    up += self.gap; // back to the end of the output, so the blank rows are not left above the region
                }
                out = (up > 0 ? string `${ESC}[${up}A` : "") + toColumn(0) + ERASE_BELOW;
            }
        }
        self.width = width;
        self.height = height;
        self.previous = ();
        self.cursorRow = 0;
        self.anchored = false; // the next draw asks where the cursor is and anchors again
        self.gap = 0;
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
        self.savedInline = {previous: self.previous, cursorRow: self.cursorRow, anchored: self.anchored, gap: self.gap};
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
        self.anchored = saved is InlineState ? saved.anchored : false;
        self.gap = saved is InlineState ? saved.gap : 0;
        self.savedInline = ();
        check self.terminal.write(ESC + "[?1049l");
    }

    # Finishes and leaves the cursor on a fresh line (see `Renderer.close`).
    #
    # + return - an error when the terminal cannot be written
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
        self.anchored = false;
        self.gap = 0;
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

    # Draws the live region (see `Renderer.draw`).
    #
    # + lines - the lines of the live region, one per row
    # + return - an error when the terminal cannot be written
    public function draw(txt:Span[][] lines) returns error? {
        self.latest = lines;
    }

    # Commits paragraphs above the live region (see `Renderer.commitProse`).
    #
    # + paragraphs - the paragraphs
    # + return - an error when the terminal cannot be written
    public function commitProse(txt:Span[][] paragraphs) returns error? {
        string out = "";
        foreach txt:Span[] paragraph in paragraphs {
            out += stripEscapes(txt:plainText(paragraph)) + "\n";
        }
        if out != "" {
            check self.terminal.write(out);
        }
    }

    # Commits a block above the live region (see `Renderer.commitBlock`).
    #
    # + lines - the lines of the block
    # + return - an error when the terminal cannot be written
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

    # Handles a change of window size (see `Renderer.resize`).
    #
    # + width - the new number of columns
    # + height - the new number of rows
    # + return - an error when the terminal cannot be written
    public function resize(int width, int height) returns error? {
        self.width = width;
    }

    # Finishes and leaves the cursor on a fresh line (see `Renderer.close`).
    #
    # + return - an error when the terminal cannot be written
    public function close() returns error? {
        txt:Span[][] last = self.latest;
        self.latest = [];
        check self.commitProse(last);
    }
}
