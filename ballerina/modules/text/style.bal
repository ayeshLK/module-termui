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

# A named ANSI color: the eight standard colors and their bright variants.
public type NamedColor "black"|"red"|"green"|"yellow"|"blue"|"magenta"|"cyan"|"white"|
    "brightBlack"|"brightRed"|"brightGreen"|"brightYellow"|"brightBlue"|"brightMagenta"|"brightCyan"|"brightWhite";

# A color from the 256-color palette.
#
# + index - the palette index, 0 to 255
public type IndexedColor record {|
    int index;
|};

# A 24-bit color.
#
# + r - red, 0 to 255
# + g - green, 0 to 255
# + b - blue, 0 to 255
public type RgbColor record {|
    int r;
    int g;
    int b;
|};

# A terminal color.
public type Color NamedColor|IndexedColor|RgbColor;

# The look of a piece of text.
#
# + fg - the foreground color; the terminal default when absent
# + bg - the background color; the terminal default when absent
# + bold - whether the text is bold
# + dim - whether the text is dimmed
# + italic - whether the text is italic
# + underline - whether the text is underlined
# + reverse - whether foreground and background are swapped
public type Style record {|
    Color fg?;
    Color bg?;
    boolean bold = false;
    boolean dim = false;
    boolean italic = false;
    boolean underline = false;
    boolean reverse = false;
|};

# A run of text that has a single style.
#
# + text - the text of the span
# + style - the style of the span
public type Span record {|
    string text;
    Style style = {};
|};

const string ESC = "\u{1b}";
const string RESET = ESC + "[0m";

final readonly & map<int> FOREGROUND_CODES = {
    black: 30,
    red: 31,
    green: 32,
    yellow: 33,
    blue: 34,
    magenta: 35,
    cyan: 36,
    white: 37,
    brightBlack: 90,
    brightRed: 91,
    brightGreen: 92,
    brightYellow: 93,
    brightBlue: 94,
    brightMagenta: 95,
    brightCyan: 96,
    brightWhite: 97
};

isolated function colorCode(Color color, boolean background) returns string {
    if color is NamedColor {
        int base = FOREGROUND_CODES.get(color);
        return (background ? base + 10 : base).toString();
    }
    string selector = background ? "48" : "38";
    if color is IndexedColor {
        return selector + ";5;" + color.index.toString();
    }
    return selector + ";2;" + color.r.toString() + ";" + color.g.toString() + ";" + color.b.toString();
}

# Builds the ANSI SGR escape sequence that switches on a style.
#
# + style - the style
# + colors - whether to include foreground and background colors; attributes such as bold are kept either way
# + return - the escape sequence, or an empty string when the style has nothing to switch on
public isolated function sgr(Style style, boolean colors = true) returns string {
    string[] codes = [];
    if style.bold {
        codes.push("1");
    }
    if style.dim {
        codes.push("2");
    }
    if style.italic {
        codes.push("3");
    }
    if style.underline {
        codes.push("4");
    }
    if style.reverse {
        codes.push("7");
    }
    if colors {
        Color? fg = style?.fg;
        if fg is Color {
            codes.push(colorCode(fg, false));
        }
        Color? bg = style?.bg;
        if bg is Color {
            codes.push(colorCode(bg, true));
        }
    }
    if codes.length() == 0 {
        return "";
    }
    return ESC + "[" + string:'join(";", ...codes) + "m";
}

# Renders spans as a string with ANSI escape sequences.
#
# Each styled span is wrapped in its escape sequence and a reset; unstyled spans are written as they are.
#
# + spans - the spans to render
# + colors - whether to emit color sequences (turn off for NO_COLOR and for non-terminal output)
# + return - the rendered string
public isolated function toAnsi(Span[] spans, boolean colors = true) returns string {
    string out = "";
    foreach Span span in spans {
        if span.text == "" {
            continue;
        }
        string sequence = sgr(span.style, colors);
        out += sequence == "" ? span.text : sequence + span.text + RESET;
    }
    return out;
}

# Joins the text of spans, dropping all styling.
#
# + spans - the spans
# + return - the plain text
public isolated function plainText(Span[] spans) returns string {
    string out = "";
    foreach Span span in spans {
        out += span.text;
    }
    return out;
}
