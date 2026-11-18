## Overview

Draws the interface: a live region that is redrawn in place at the bottom of the terminal, and finished
output that is written once into the normal scrollback above it.

- **`InlineRenderer`** is the interactive renderer. `draw` replaces the live region with lines of
  styled text and writes only the cells that changed (relative cursor movement, one write per call).
  `commitProse` and `commitBlock` write finished output above the region and draw the region again
  below it. `resize`, `enterFullScreen`, `leaveFullScreen`, and `close` cover the rest of the life cycle.
- **`PlainRenderer`** is for output that is not a terminal: committed output as plain lines with no
  styling or cursor control, and the live region only once, as its final state, when it is closed.
- **`Buffer`** is the grid of cells behind a frame. `InlineRenderer.frame()`, `bufferLines`, and
  `cellAt` let a test check what was drawn, including the style of each cell, without a terminal.

### Live region and commit-above

The region starts on the cursor's row, which must be at the start of a line, and is at most as tall as the
terminal (extra lines at the top are dropped). After every `draw` the cursor is at column 0 of the
region's last row. Committed output is never redrawn:

- `commitProse` writes each paragraph as one logical line, so the terminal wraps it and, in terminals
  that re-wrap on resize, can re-wrap it later. A newline inside a paragraph is written as carriage
  return plus line feed.
- `commitBlock` wraps each line to the width at that moment, for output whose layout cannot be
  re-wrapped (tables, boxes, diffs).

### Resize

Call `resize` when the window changes size, then `draw` again. `resize` clears the old region and the
renderer forgets it. Committed history is never re-laid out: prose is re-wrapped by terminals that
reflow, and blocks keep the width they were committed at.

To clear the right rows the renderer must know how many rows the old region occupies after the terminal
has (or has not) re-wrapped it. The `reflow` option says which: with `true` (the default, as most terminals
behave) each old row takes `ceil(content width / new width)` rows; with `false` the region keeps its
height. If the option does not match the terminal, stale rows can be left behind or too many rows
cleared, so set it to match the terminal you target. Redrawing happens at the next `draw`, so there is a
short moment with no region.

### Full screen

`enterFullScreen` switches to the alternate screen, where `draw` fills the whole terminal and `commit*`
is not available. `leaveFullScreen` restores the normal screen as it was, including the inline region.

### Example

```ballerina
import ayesha/termui.render;
import ayesha/termui.term;

public function main() returns error? {
    term:FakeTerminal terminal = new (30, 8);
    render:InlineRenderer renderer = new (terminal, 30, 8);
    check renderer.commitProse([[{text: "Hello!"}]]);
    check renderer.draw([[{text: "> typing"}]]);
    // terminal.screenText() == "Hello!\n> typing"
}
```
