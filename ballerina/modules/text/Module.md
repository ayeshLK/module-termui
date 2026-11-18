## Overview

Styled terminal text: styles and spans, display width, and wrapping. Everything here is pure and
`isolated`, so it can be called from anywhere, including effects.

- **Styles and spans.** A `Span` is a piece of text with a `Style` (foreground and background
  color, bold, dim, italic, underline, reverse). `toAnsi` renders spans with ANSI escape sequences,
  and turns the color sequences off when `colors` is `false` (for `NO_COLOR` and non-terminal output).
  Attributes such as bold are kept, because they are not colors.
- **Display width.** `displayWidth` measures how many terminal columns a string takes: wide (CJK,
  emoji) characters count two, combining marks and zero-width characters count none, ANSI escape
  sequences count none, and a zero-width joiner merges the next character into the previous one.
  The range tables are abbreviated, and code points that are not listed count one column.
- **Wrapping.** `wrap` and `wrapText` break lines at spaces to a column width, split a word that is
  wider than the width, keep styles on both sides of a break, and support a first-line indent and a
  hanging (continuation) indent. Spaces at a wrap point are dropped, spaces at the start of the text
  or after a newline are kept, a newline forces a break, and a tab counts as one space.

### Example

```ballerina
import ayesha/termui.text;
import ballerina/io;

public function main() {
    text:Span[] spans = [
        {text: "error: ", style: {bold: true, fg: "red"}},
        {text: "the quick brown fox jumps over the lazy dog"}
    ];

    // Wrap to 24 columns, indenting continuation lines under the message.
    foreach text:Span[] line in text:wrap(spans, 24, 0, 7) {
        io:println(text:toAnsi(line, colors = false));
    }

    io:println(text:displayWidth("日本語")); // 6
}
```

This prints the following, with `error:` in bold because attributes are kept when colors are off:

```
error: the quick brown
       fox jumps over
       the lazy dog
6
```
