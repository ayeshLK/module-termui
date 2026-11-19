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
import ayesha/termui.text;

# What was typed when the user submitted the editor.
#
# + text - the submitted text, possibly with several lines
public type Submitted record {|
    string text;
|};

# What handling an event did: `edited` when the editor used the event (redraw it), `ignored` when the
# event is not one the editor uses (Ctrl+C, Escape, Tab and so on, for the program to act on), or the
# submitted text when Enter was pressed.
public type EditResult "edited"|"ignored"|Submitted;

# A text input for a terminal program: a text, a cursor, readline-style editing keys, multi-line input,
# paste, and a history. It holds no terminal; the program passes it the key and paste events it receives
# and draws what `render` returns.
#
# It is `isolated`, so a program (which is itself `isolated`) can hold one in a field.
public isolated class LineEditor {
    private final State state;

    # Creates an editor.
    #
    # + multiline - whether Alt+Enter and Ctrl+J insert a line break (when `false` the text is a single
    #               line and pasted line breaks become spaces)
    # + history - earlier submissions, oldest first, to walk through with Up and Down
    # + maxHistory - how many submissions to remember
    public isolated function init(boolean multiline = true, string[] history = [], int maxHistory = 100) {
        self.state = newState(multiline, history.clone(), maxHistory);
    }

    # Applies a key press or a paste.
    #
    # + event - the event the program received
    # + return - `edited` when the editor used it, `ignored` when it did not, or the submitted text
    public isolated function handleEvent(term:KeyEvent|term:PasteEvent event) returns EditResult {
        readonly & (term:KeyEvent|term:PasteEvent) copy = event.cloneReadOnly();
        lock {
            return applyEvent(self.state, copy).clone();
        }
    }

    # The text being edited.
    #
    # + return - the text, with line breaks as `\n`
    public isolated function text() returns string {
        lock {
            return currentText(self.state);
        }
    }

    # Where the cursor is.
    #
    # + return - the number of characters before the cursor (a letter with its combining marks is one)
    public isolated function cursor() returns int {
        lock {
            return self.state.cursorAt;
        }
    }

    # The remembered submissions.
    #
    # + return - the history, oldest first, for the program to keep between runs
    public isolated function history() returns string[] {
        lock {
            return self.state.entries.clone();
        }
    }

    # Draws the editor.
    #
    # The first row starts with the prompt and the following rows are indented by its width. Long lines
    # are wrapped by display width, a double-width character is never split, and the cursor is the
    # character under it drawn in reverse video (a reverse space at the end of a line).
    #
    # + width - the number of columns available
    # + prompt - what to show before the text
    # + style - the style of the text
    # + return - the rows of the editor as styled text, for the program's `view`
    public isolated function render(int width, string prompt = "> ", text:Style style = {}) returns text:Span[][] {
        text:Style & readonly look = style.cloneReadOnly();
        lock {
            return drawRows(self.state, width, prompt, look).clone();
        }
    }
}

// ---- state ----------------------------------------------------------------------------------------

// One character of the text as the user sees it is a unit: a code point together with the combining
// marks that follow it, so the cursor never stops between a letter and its accent. A line break is a
// unit of its own.
const string LINE_BREAK = "\n";

type State record {|
    string[] units;
    int cursorAt;
    boolean multiline;
    string[] entries;
    int maxHistory;
    int walking;
    string draft;
|};

type Cell record {|
    string text;
    boolean cursor;
|};

isolated function newState(boolean multiline, string[] history, int maxHistory) returns State {
    State state = {units: [], cursorAt: 0, multiline, entries: [], maxHistory: int:max(0, maxHistory), walking: -1, draft: ""};
    foreach string entry in history {
        remember(state, multiline ? entry : re `\n`.replaceAll(entry, " "));
    }
    return state;
}

isolated function currentText(State s) returns string {
    return string:'join("", ...s.units);
}

// ---- keys -------------------------------------------------------------------------------------------

isolated function applyEvent(State s, term:KeyEvent|term:PasteEvent event) returns EditResult {
    if event is term:PasteEvent {
        insertText(s, normalisePaste(event.text, s.multiline));
        return "edited";
    }
    string:Char|term:NamedKey key = event.key;
    if key is term:NamedKey {
        return handleNamed(s, key, event.ctrl, event.alt);
    }
    if event.ctrl && !event.alt {
        return handleControl(s, key);
    }
    if event.alt && !event.ctrl {
        return handleAlt(s, key);
    }
    if event.ctrl || event.alt {
        return "ignored";
    }
    insertText(s, key);
    return "edited";
}

isolated function handleNamed(State s, term:NamedKey key, boolean ctrl, boolean alt) returns EditResult {
    match key {
        "enter" => {
            if alt && !ctrl {
                return lineBreak(s);
            }
            if ctrl || alt {
                return "ignored";
            }
            return submitFrom(s);
        }
        "backspace" => {
            if ctrl || alt {
                return "ignored";
            }
            if s.cursorAt > 0 {
                removeRange(s, s.cursorAt - 1, s.cursorAt);
            }
            return "edited";
        }
        "delete" => {
            if ctrl || alt {
                return "ignored";
            }
            removeRange(s, s.cursorAt, s.cursorAt + 1);
            return "edited";
        }
        "left" => {
            s.cursorAt = (ctrl || alt) ? wordStart(s, s.cursorAt) : int:max(0, s.cursorAt - 1);
            return "edited";
        }
        "right" => {
            s.cursorAt = (ctrl || alt) ? wordEnd(s, s.cursorAt) : int:min(s.units.length(), s.cursorAt + 1);
            return "edited";
        }
        "home" => {
            s.cursorAt = lineStart(s, s.cursorAt);
            return "edited";
        }
        "end" => {
            s.cursorAt = lineEnd(s, s.cursorAt);
            return "edited";
        }
        "up" => {
            if ctrl || alt {
                return "ignored";
            }
            moveUp(s);
            return "edited";
        }
        "down" => {
            if ctrl || alt {
                return "ignored";
            }
            moveDown(s);
            return "edited";
        }
    }
    return "ignored";
}

isolated function handleControl(State s, string:Char key) returns EditResult {
    match key {
        "a" => {
            s.cursorAt = lineStart(s, s.cursorAt);
        }
        "e" => {
            s.cursorAt = lineEnd(s, s.cursorAt);
        }
        "b" => {
            s.cursorAt = int:max(0, s.cursorAt - 1);
        }
        "f" => {
            s.cursorAt = int:min(s.units.length(), s.cursorAt + 1);
        }
        "w" => {
            removeRange(s, wordStart(s, s.cursorAt), s.cursorAt);
        }
        "u" => {
            removeRange(s, lineStart(s, s.cursorAt), s.cursorAt);
        }
        "k" => {
            removeRange(s, s.cursorAt, lineEnd(s, s.cursorAt));
        }
        "d" => {
            if s.units.length() == 0 {
                return "ignored";
            }
            removeRange(s, s.cursorAt, s.cursorAt + 1);
        }
        "j" => {
            return lineBreak(s);
        }
        _ => {
            return "ignored";
        }
    }
    return "edited";
}

isolated function handleAlt(State s, string:Char key) returns EditResult {
    match key {
        "b" => {
            s.cursorAt = wordStart(s, s.cursorAt);
        }
        "f" => {
            s.cursorAt = wordEnd(s, s.cursorAt);
        }
        "d" => {
            removeRange(s, s.cursorAt, wordEnd(s, s.cursorAt));
        }
        _ => {
            return "ignored";
        }
    }
    return "edited";
}

// ---- editing ----------------------------------------------------------------------------------------

isolated function lineBreak(State s) returns EditResult {
    if !s.multiline {
        return "ignored";
    }
    insertUnits(s, [LINE_BREAK]);
    return "edited";
}

isolated function submitFrom(State s) returns Submitted {
    string submitted = currentText(s);
    remember(s, submitted);
    s.units = [];
    s.cursorAt = 0;
    s.walking = -1;
    s.draft = "";
    return {text: submitted};
}

// Adds a submission to the history, unless it is blank or repeats the newest entry.
isolated function remember(State s, string entry) {
    if entry.trim() == "" || s.maxHistory == 0 {
        return;
    }
    if s.entries.length() > 0 && s.entries[s.entries.length() - 1] == entry {
        return;
    }
    s.entries.push(entry);
    if s.entries.length() > s.maxHistory {
        s.entries = s.entries.slice(s.entries.length() - s.maxHistory);
    }
}

isolated function insertText(State s, string value) {
    insertUnits(s, splitUnits(value));
}

isolated function insertUnits(State s, string[] fresh) {
    string[] added = fresh;
    // a combining mark typed after a letter belongs to that letter
    if added.length() > 0 && s.cursorAt > 0 && isMark(added[0]) && s.units[s.cursorAt - 1] != LINE_BREAK {
        s.units[s.cursorAt - 1] = s.units[s.cursorAt - 1] + added[0];
        added = added.slice(1);
    }
    s.units = [...s.units.slice(0, s.cursorAt), ...added, ...s.units.slice(s.cursorAt)];
    s.cursorAt += added.length();
}

isolated function removeRange(State s, int first, int last) {
    int begin = int:max(0, first);
    int end = int:min(s.units.length(), last);
    if end <= begin {
        return;
    }
    s.units = [...s.units.slice(0, begin), ...s.units.slice(end)];
    s.cursorAt = begin;
}

// ---- positions --------------------------------------------------------------------------------------

isolated function lineStart(State s, int at) returns int {
    int index = at;
    while index > 0 && s.units[index - 1] != LINE_BREAK {
        index -= 1;
    }
    return index;
}

isolated function lineEnd(State s, int at) returns int {
    int index = at;
    while index < s.units.length() && s.units[index] != LINE_BREAK {
        index += 1;
    }
    return index;
}

isolated function wordStart(State s, int at) returns int {
    int index = at;
    while index > 0 && isSpace(s.units[index - 1]) {
        index -= 1;
    }
    while index > 0 && !isSpace(s.units[index - 1]) {
        index -= 1;
    }
    return index;
}

isolated function wordEnd(State s, int at) returns int {
    int index = at;
    int count = s.units.length();
    while index < count && isSpace(s.units[index]) {
        index += 1;
    }
    while index < count && !isSpace(s.units[index]) {
        index += 1;
    }
    return index;
}

// ---- up and down: between lines, and at the first or last line through the history --------------------

isolated function moveUp(State s) {
    int begin = lineStart(s, s.cursorAt);
    if begin > 0 {
        int column = s.cursorAt - begin;
        int previousEnd = begin - 1;
        s.cursorAt = int:min(lineStart(s, previousEnd) + column, previousEnd);
        return;
    }
    if s.entries.length() == 0 {
        return;
    }
    if s.walking == -1 {
        s.draft = currentText(s);
        s.walking = s.entries.length() - 1;
    } else if s.walking > 0 {
        s.walking -= 1;
    } else {
        return;
    }
    replaceWith(s, s.entries[s.walking]);
}

isolated function moveDown(State s) {
    int end = lineEnd(s, s.cursorAt);
    if end < s.units.length() {
        int column = s.cursorAt - lineStart(s, s.cursorAt);
        int nextStart = end + 1;
        s.cursorAt = int:min(nextStart + column, lineEnd(s, nextStart));
        return;
    }
    if s.walking == -1 {
        return;
    }
    if s.walking < s.entries.length() - 1 {
        s.walking += 1;
        replaceWith(s, s.entries[s.walking]);
    } else {
        s.walking = -1;
        replaceWith(s, s.draft);
    }
}

isolated function replaceWith(State s, string value) {
    s.units = splitUnits(value);
    s.cursorAt = s.units.length();
}

// ---- drawing ------------------------------------------------------------------------------------------

isolated function drawRows(State s, int width, string prompt, text:Style style) returns text:Span[][] {
    int promptWidth = text:displayWidth(prompt);
    int room = int:max(1, width - promptWidth);
    Cell[][] rows = [[]];
    int column = 0;
    int count = s.units.length();
    foreach int index in 0 ... count {
        boolean here = index == s.cursorAt;
        if index == count || s.units[index] == LINE_BREAK {
            if here {
                if column + 1 > room {
                    rows.push([]);
                    column = 0;
                }
                rows[rows.length() - 1].push({text: " ", cursor: true});
                column += 1;
            }
            if index < count {
                rows.push([]);
                column = 0;
            }
            continue;
        }
        string unit = s.units[index];
        int cellWidth = text:displayWidth(unit);
        if column > 0 && column + cellWidth > room {
            rows.push([]);
            column = 0;
        }
        rows[rows.length() - 1].push({text: unit, cursor: here});
        column += cellWidth;
    }
    string indent = "";
    foreach int _ in 0 ..< promptWidth {
        indent += " ";
    }
    text:Span[][] lines = [];
    foreach int row in 0 ..< rows.length() {
        text:Span[] spans = [];
        string lead = row == 0 ? prompt : indent;
        if lead != "" {
            spans.push({text: lead});
        }
        string run = "";
        foreach Cell cell in rows[row] {
            if cell.cursor {
                if run != "" {
                    spans.push({text: run, style});
                    run = "";
                }
                text:Style highlighted = {bold: style.bold, dim: style.dim, italic: style.italic, underline: style.underline,
                    reverse: true};
                text:Color? fg = style?.fg;
                if fg is text:Color {
                    highlighted.fg = fg;
                }
                text:Color? bg = style?.bg;
                if bg is text:Color {
                    highlighted.bg = bg;
                }
                spans.push({text: cell.text, style: highlighted});
            } else {
                run += cell.text;
            }
        }
        if run != "" {
            spans.push({text: run, style});
        }
        lines.push(spans);
    }
    return lines;
}

// ---- text helpers -------------------------------------------------------------------------------------

// Splits text into units: each character followed by its combining marks.
isolated function splitUnits(string value) returns string[] {
    string[] units = [];
    foreach string:Char char in value {
        if units.length() > 0 && char != LINE_BREAK && units[units.length() - 1] != LINE_BREAK && text:displayWidth(char) == 0 {
            units[units.length() - 1] = units[units.length() - 1] + char;
        } else {
            units.push(char);
        }
    }
    return units;
}

// A unit that is only combining marks (nothing to attach to yet).
isolated function isMark(string unit) returns boolean {
    return unit != LINE_BREAK && text:displayWidth(unit) == 0;
}

isolated function isSpace(string unit) returns boolean {
    return unit == " " || unit == LINE_BREAK || unit == "\t";
}

// Pasted text as the editor stores it: line feeds only, line breaks turned into spaces for a
// single-line editor, tabs as four spaces, other control characters dropped.
isolated function normalisePaste(string pasted, boolean multiline) returns string {
    string value = re `\r\n|\r`.replaceAll(pasted, "\n");
    string kept = "";
    foreach string:Char char in value {
        int code = char.toCodePointInt();
        if char == LINE_BREAK {
            kept += multiline ? LINE_BREAK : " ";
        } else if char == "\t" {
            kept += "    ";
        } else if code >= 0x20 && code != 0x7F {
            kept += char;
        }
    }
    return kept;
}
