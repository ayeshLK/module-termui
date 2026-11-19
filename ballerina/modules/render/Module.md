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

### Anchoring to the bottom

By default the region starts where the cursor is, so on a fresh screen the interface sits at the top. With
`anchorBottom` the region is kept on the last rows of the terminal instead, the way a chat input is:

```
   existing output          rows above the region, left alone
   blank rows (the gap)     used before anything scrolls
   live region              always ends on the last row
```

The renderer asks the terminal once where its cursor is (see `term:CursorReporter`), puts the region on the
last rows, and scrolls the screen by exactly the rows it lacks, never overwriting anything. Then:

- committed output is written into the gap, directly below the existing output, and the region does not
  move; a paragraph that wraps counts every row it takes;
- a growing region grows upward into the gap, and a shrinking one returns its rows to it, so the region
  always keeps the last row;
- when the gap is used up the screen scrolls exactly as it does without the option, and everything that
  scrolls off the top, including what was on screen before, stays in the terminal's scrollback. No blank
  row is ever written into the scrollback.

Limits: the option has no effect when the terminal does not report its cursor (the region is drawn as
usual), and a header pinned at the top is not possible, because that needs a scroll region, which loses
the native scrollback; use `enterFullScreen` for such an interface. Text outside ASCII is measured with a
second cursor report after it is written, because terminals may draw some characters wider than expected.
Other programs writing to the terminal while the renderer runs are not accounted for. After a resize the
region is cleared and anchored again at the next `draw`; the terminal's own re-wrapping may push earlier
output, and some of the gap, into its scrollback.

```ballerina
import ayesha/termui.render;
import ayesha/termui.term;

public function main() returns error? {
    term:FakeTerminal terminal = new (30, 8);
    check terminal.write("banner\r\n");
    render:InlineRenderer renderer = new (terminal, 30, 8, anchorBottom = true);
    check renderer.draw([[{text: "> typing"}]]);
    check renderer.commitProse([[{text: "Hello!"}]]);
    // terminal.screenLines() == ["banner", "Hello!", "", "", "", "", "", "> typing"]
}
```

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

### Stability

Supported: the `Renderer` type, `InlineRenderer`, `PlainRenderer`, and the cell buffer (`Buffer`, `Cell`,
`newBuffer`, `bufferFromLines`, `bufferLines`, `cellAt`), which is the way to inspect a rendered frame,
including each cell's style, in a test. The five methods of `Renderer` (`draw`, `commitProse`,
`commitBlock`, `resize`, `close`) are the whole contract: a renderer that implements only those works
with the runtime. Later abilities arrive as separate capability types that a renderer may also implement.

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
