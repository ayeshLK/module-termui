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

type AtomKind "char"|"space"|"newline";

// The smallest unit the wrapper moves: one displayed character (or escape sequence) with its width
// and style. Combining marks and escape sequences have width 0, so they stay with the character
// before them.
type Atom record {|
    string text;
    int width;
    Style style;
    AtomKind kind;
|};

type LineState record {|
    Span[][] lines;
    Atom[] current;
    int currentWidth;
    int indent;
    int restIndent;
    int width;
|};

isolated function spaces(int count) returns string {
    string out = "";
    foreach int _ in 0 ..< count {
        out += " ";
    }
    return out;
}

isolated function toAtoms(Span[] spans) returns Atom[] {
    Atom[] atoms = [];
    boolean joined = false;
    foreach Span span in spans {
        string:Char[] chars = toChars(span.text);
        int i = 0;
        while i < chars.length() {
            int escape = escapeLength(chars, i);
            if escape > 0 {
                atoms.push({text: string:'join("", ...chars.slice(i, i + escape)), width: 0, style: span.style, kind: "char"});
                i += escape;
                continue;
            }
            int codePoint = chars[i].toCodePointInt();
            i += 1;
            if codePoint == 0x0A {
                atoms.push({text: "\n", width: 0, style: span.style, kind: "newline"});
                joined = false;
            } else if codePoint == 0x20 || codePoint == 0x09 {
                atoms.push({text: " ", width: 1, style: span.style, kind: "space"});
                joined = false;
            } else {
                [int, boolean] [cells, nextJoined] = cellWidth(codePoint, joined);
                joined = nextJoined;
                atoms.push({text: chars[i - 1], width: cells, style: span.style, kind: "char"});
            }
        }
    }
    return atoms;
}

isolated function available(LineState state) returns int {
    return int:max(1, state.width - state.indent);
}

isolated function fits(LineState state, int extra) returns boolean {
    return state.currentWidth + extra <= available(state);
}

isolated function addAtom(LineState state, Atom atom) {
    state.current.push(atom);
    state.currentWidth += atom.width;
}

// Turns the atoms of the current line into spans (merging neighbours that share a style), adds the
// line to the output, and starts the next line with the continuation indent.
isolated function flushLine(LineState state) {
    Span[] spans = [];
    if state.current.length() > 0 && state.indent > 0 {
        spans.push({text: spaces(state.indent)});
    }
    foreach Atom atom in state.current {
        int last = spans.length() - 1;
        if last >= 0 && spans[last].style == atom.style {
            spans[last].text += atom.text;
        } else {
            spans.push({text: atom.text, style: atom.style});
        }
    }
    state.lines.push(spans);
    state.current = [];
    state.currentWidth = 0;
    state.indent = state.restIndent;
}

# Wraps styled text to a column width.
#
# Lines break at spaces; a word wider than the width is split at the width limit. Styles are kept on
# both sides of a break, and the display width (not the character count) decides what fits. Spaces
# at a wrap point are dropped, spaces at the start of the text or after a newline are kept, and a
# newline in the text forces a break. A tab counts as one space.
#
# + spans - the text to wrap
# + width - the number of columns available
# + firstIndent - the indent of the first line
# + restIndent - the indent of every following line (use it for a hanging indent under a list marker)
# + return - the wrapped lines, each as spans; empty text gives one empty line
public isolated function wrap(Span[] spans, int width, int firstIndent = 0, int restIndent = 0) returns Span[][] {
    Atom[] atoms = toAtoms(spans);
    LineState state = {lines: [], current: [], currentWidth: 0, indent: firstIndent, restIndent, width};
    Atom[] pending = [];
    int pendingWidth = 0;
    boolean keepLeading = true;
    int i = 0;
    while i < atoms.length() {
        Atom atom = atoms[i];
        if atom.kind == "newline" {
            flushLine(state);
            pending = [];
            pendingWidth = 0;
            keepLeading = true;
            i += 1;
            continue;
        }
        if atom.kind == "space" {
            pending.push(atom);
            pendingWidth += atom.width;
            i += 1;
            continue;
        }
        int end = i;
        int wordWidth = 0;
        while end < atoms.length() && atoms[end].kind == "char" {
            wordWidth += atoms[end].width;
            end += 1;
        }
        if state.current.length() == 0 {
            if keepLeading {
                foreach Atom space in pending {
                    addAtom(state, space);
                }
            }
        } else if fits(state, pendingWidth + wordWidth) {
            foreach Atom space in pending {
                addAtom(state, space);
            }
        } else {
            flushLine(state);
        }
        pending = [];
        pendingWidth = 0;
        keepLeading = false;
        foreach Atom part in atoms.slice(i, end) {
            if state.current.length() > 0 && !fits(state, part.width) {
                flushLine(state);
            }
            addAtom(state, part);
        }
        i = end;
    }
    if state.current.length() > 0 || state.lines.length() == 0 {
        flushLine(state);
    }
    return state.lines;
}

# Wraps plain text to a column width.
#
# + text - the text to wrap
# + width - the number of columns available
# + firstIndent - the indent of the first line
# + restIndent - the indent of every following line
# + return - the wrapped lines as strings
public isolated function wrapText(string text, int width, int firstIndent = 0, int restIndent = 0) returns string[] {
    string[] lines = [];
    foreach Span[] line in wrap([{text}], width, firstIndent, restIndent) {
        lines.push(plainText(line));
    }
    return lines;
}
