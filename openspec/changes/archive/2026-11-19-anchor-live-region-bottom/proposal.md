# Proposal

## Why

`InlineRenderer` starts the live region on the cursor's current row, so in an agent-style app such as `examples/agent-harness` the prompt appears directly under the welcome banner, in the middle of an empty terminal, and only reaches the bottom once enough output has scrolled. Chat-style tools show the input on the bottom row from the first frame. Today an app can only approximate that by committing blank lines at startup, which needs the terminal height up front, fills the scrollback with blanks, and breaks on resize. See issue #3 and the exploration that preceded this change.

## What Changes

- Add an opt-in `anchorBottom` option (default `false`, so current behavior is unchanged) that keeps the live region on the last rows of the terminal from the first frame, with the output so far staying where it is above it.
- Track the blank rows between the output and the region (the "gap") and use them before anything scrolls: committed output is written into the gap directly below the existing content, the region grows upward into the gap, and a shrinking region gives rows back. Only when the gap is used up does the screen scroll, as it does today, and earlier content then goes into the scrollback intact. No blank rows ever enter the scrollback.
- Position the region at the bottom on the first draw with a sequence that never overwrites content: line feeds first (which scroll only by the shortfall), then a clamped cursor move to the last row, then back up by the region height minus one.
- Learn the cursor's row once, at the first draw and again after a resize, by asking the terminal for it (the cursor position report). This is a new optional terminal capability, offered through a separate interface so existing `Terminal` implementations keep working. When a terminal cannot report it (or the renderer is plain, piped, or full-screen), `anchorBottom` has no effect and drawing behaves exactly as today.
- Pass the option through `termui:Options`, `render:InlineRenderer`, and `Interface`, and turn it on in `examples/agent-harness`.
- Start with a spike that proves the cursor position query end to end on a real pseudo-terminal, with a go or no-go before the renderer work builds on it.
- Out of scope: pinning a banner or header at the top (it cannot be done without giving up the terminal's native scrollback; the alternate-screen mode remains the option for that), alternate-screen changes, and any change to how committed prose is wrapped.

## Capabilities

### New Capabilities

None.

### Modified Capabilities

- `buffer-renderer`: adds the bottom-anchored live region, gap use on commit, growth and shrink, exhaustion behavior, resize re-anchoring, and the no-effect cases.
- `terminal-backend`: adds the optional cursor position report, with a timeout and an unknown answer, for the Unix terminal and the in-memory terminal.
- `mvu-runtime`: adds the `anchorBottom` run option and its pass-through to the renderer.

## Impact

- New public API: a `CursorReporter` interface in `term`, `anchorBottom` on `InlineRenderer.init`, `Options`, and `Interface`. All additive with defaults; no existing signature changes meaning.
- Touched code: the renderer's first-draw, grow, shrink, commit, and resize paths; the input decoder (cursor position replies); `UnixTerminal` and `FakeTerminal`; `run` and `Interface`.
- The pty test helper learns to answer a cursor position query so the real-terminal behavior can be tested without a real terminal.
- `examples/agent-harness` and its README recording change to show the anchored input.
- Behavior for existing programs is unchanged, because the option is off by default.
