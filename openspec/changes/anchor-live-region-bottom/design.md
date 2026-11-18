# Design

## Context

See `proposal.md` for the motivation. Today `InlineRenderer` draws its first frame from the cursor's row and addresses everything relative to the region (it never knows an absolute row). Commits clear the region, write the lines at the region's top, and draw the region again below them. A region that shrinks keeps its top row, so blank rows are left under it. The renderer knows the terminal's height (`height`, updated on resize) but not where the cursor is.

Three facts from the exploration shape the design:

- Clamped cursor moves are reliable: `CSI n B` and `CSI n A` stop at the bottom and top rows (the in-memory terminal does the same), so moving to the last row needs no row arithmetic.
- Anchoring alone (the region on the last rows) is easy. What makes it look right is **using the blank rows above the region** before scrolling anything; without that, the first committed line scrolls the banner away while blank rows remain, and those blank rows later travel into the scrollback.
- Using the blank rows requires knowing how many there are, which requires the cursor's row once. Nothing provides that today.

## Goals / Non-Goals

**Goals:**
- Input on the bottom row from the first frame, with the banner and earlier output untouched and visible until the conversation actually fills the screen.
- No blank rows ever in the scrollback, and no overwritten content, in any case.
- Strictly opt-in and additive: existing programs and existing `Terminal` implementations are unaffected.
- Testable without a terminal, and verifiable on a real pseudo-terminal.

**Non-Goals:**
- A pinned header at the top: it cannot coexist with native scrollback (scroll regions generally discard what scrolls out of a region that does not start at the top). The alternate screen remains the option for that.
- Changing how prose is wrapped or how resize reflow is handled.
- Anchoring for the plain renderer, pipes, headless, or full-screen mode.

## Decisions

**1. Gap-absorbing anchoring (model A), not "anchor and leave commits unchanged" (model B).** The renderer keeps the layout

```
   +-------------------------+
   |  existing output        |   rows 0 .. top-1 (not touched)
   +-------------------------+
   |  gap: g blank rows      |   rows top .. H-M-1
   +-------------------------+
   |  live region: M rows    |   rows H-M .. H-1   (always ends on the last row)
   +-------------------------+
```

with two numbers of state, `gap` and the region's height `M`, plus the fact that the region is anchored. Alternatives: (B) anchor and keep commits as they are; simplest and needs no new capability, but the screen scrolls on the first commit, the banner leaves the visible screen after one turn while blank rows remain, and the gap eventually enters the scrollback. (Blank lines committed at startup) needs the height up front, pollutes the scrollback, and breaks on resize. (Alternate screen) loses native scrollback, selection, and search.

**2. The cursor row comes from a terminal cursor position report, requested once per anchoring.** At the first draw, and at the first draw after a resize, the renderer asks for the cursor's row `r`. With `M` the new region height and `H` the terminal height:

```
   scroll needed  S = max(0, r + M - H)
   write:  CSI H B          down to the last row (clamped, rows below are blank)
           S line feeds     scroll the screen by exactly the shortfall (S is 0 when there is room)
           CSI (M-1) A      up to the region's top row (H - M)
   gap = max(0, H - M - r)
```

This never overwrites content: if there is no room, the screen scrolls by exactly the shortfall and the existing output moves up intact. Alternative considered: skip the query and use "N-1 line feeds, clamp down, up N-1" (it also positions the region safely) but it cannot say how many blank rows exist, which forces model B.

**3. The report is an optional capability behind a separate interface.** `term:CursorReporter` is an isolated object type with one method returning the cursor position, or `()` when unknown. The renderer asks `terminal is term:CursorReporter` and treats a missing capability, an error, or `()` as "unknown", in which case anchoring has no effect (the region is drawn as today). Alternative: add the method to `Terminal`, which would break every custom implementation and force output-only terminals to implement a stub.

**4. `UnixTerminal` asks by writing the query and waiting for the reply on the input it already reads.** It writes `ESC [ 6 n`, marks a request as outstanding, and polls a lock-guarded field that the input path fills when the decoder finds the reply, for a short timeout (200 ms to start with; to be confirmed by the spike). A terminal that never answers costs one timeout, after which the capability is remembered as unsupported and later calls return `()` at once. The reply `ESC [ row ; col R` collides with the sequence for Ctrl+F3 (`ESC [ 1 ; 5 R`), so the decoder only treats it as a reply while a request is outstanding. This needs `nextEvent` to be running, which `run` guarantees; a renderer used on its own gets `()`. Alternatives: querying inside `acquire` through the `stty` shell (a blocking read with no timeout of its own would hang on terminals that do not reply, and the shell timeout would fail the whole acquire), and reading the reply directly from the device (it would race the reader strand).

**5. The region is diffed aligned at its bottom row.** The previous and next frames are compared by absolute row counted from the last row, so a region that grows or shrinks keeps its bottom rows where they are and only changed rows are rewritten. Anchored drawing therefore needs no special case for the prompt that the runtime appends below the view.

**6. Growth, shrink, and commit all go through the gap first.**

```
   grow by d:    a = min(gap, d)        region's top moves up a rows into the gap
                 d - a rows remain      screen scrolls by d - a (line feeds at the bottom first)
   shrink by d:  vacated top rows are erased and become gap; the region keeps the last row
   commit K rows: a = min(gap, K)       first a rows are written into the gap, directly below the
                                        existing output (cursor moved up from the region), the
                                        region is not touched
                  K - a rows remain     written by the existing commit path, which scrolls
```

When the gap reaches zero the behavior is exactly today's: further commits scroll, and what scrolls off the top, banner included, goes into the scrollback. No blank row can reach the scrollback because the gap is always filled before any scrolling.

**7. Rows a committed line occupies are computed by simulating the terminal's wrapping.** Blocks are already wrapped by the renderer. For prose the row count is found by placing each character by its display width (a wide character that does not fit at the right edge moves to the next row), the same way the in-memory terminal wraps. Where this can disagree with a real terminal (unusual wide or ambiguous-width characters), the gap would drift; to contain that, a commit that contains such characters re-measures the cursor with a report afterwards and resets `gap` from it.

**8. Resize clears the region as today and drops the anchored state.** The next draw queries the cursor again and anchors again, so nothing from before the resize is trusted.

**9. Option plumbing is additive.** `InlineRenderer.init(..., boolean reflow = true, boolean anchorBottom = false)`; `termui:Options.anchorBottom = false`, passed to the renderer `run` creates; `Interface.renderer(reflow, anchorBottom)` and `Interface.run(program, initialCommand, anchorBottom = false)`, so a program using `Interface` can turn it on in one place. In the interactive-off cases (plain renderer, piped, headless, full-screen) the option is ignored.

**10. Testing.** `FakeTerminal` implements `CursorReporter` from its virtual screen, so first-draw anchoring, gap use, growth, shrink, exhaustion, and resize are covered by ordinary renderer tests. For the real backend, the pty test helper gains an operation that answers a cursor position query with a configured row, which also exercises the timeout and the Ctrl+F3 ambiguity. `examples/agent-harness` turns the option on and its end-to-end check asserts that the first frame's input is on the last row and the banner is still visible after the first turn.

## Risks / Trade-offs

- [A terminal does not answer cursor position queries] -> One timeout of about 200 ms, then the capability is marked unsupported and anchoring is a no-op; behavior is exactly today's. The spike confirms the timeout and the fallback before the renderer work starts.
- [A terminal answers slowly or the input path is busy] -> The wait is bounded; an unknown answer is always safe.
- [Gap accounting drifts from the real screen] -> Exact row simulation for prose, a re-measure after commits that contain wide or ambiguous-width characters, and clamping so a wrong count can only cause a scroll, never an overwrite of the region.
- [Other writers share the terminal (a library logging to the terminal while the app runs)] -> The renderer already assumes it owns the region; anchoring adds the assumption that it owns the screen below the output. Documented.
- [The reply bytes look like a key] -> Recognized only while a request is outstanding (decision 4).
- [`CSI n B` is assumed to clamp at the last row] -> True for the terminals targeted (xterm-compatible, tmux); the spike checks it on the available terminals, and a terminal that does not clamp would only lose the optimization (the sequence also reaches the last row by scrolling).
- [Scrollback behavior is terminal-dependent] -> The guarantee is stated in terms of what the application writes (no blank rows, nothing overwritten); that scrolled-off lines are kept is the terminal's normal behavior outside the alternate screen.
- [A one-time delay at the first draw] -> At most one timeout, only on terminals that do not answer, and only when the option is on.

## Open Questions

- The timeout value (200 ms is a starting point; the spike measures real latencies and decides).
- Whether `Interface` should ever turn anchoring on by default for the interactive mode; kept off until it has been used for a while.

## Spike results

Gathered while applying group 1 (2026-11-18).

- **Helper answers the query (1.1).** The pty helper's new `cpr` op reads until it sees `ESC [ 6 n` and replies `ESC [ row ; col R` (1-based, like a terminal), or stays silent. Checked from a throwaway pty client: reply `1b 5b 37 3b 33 52` for row 7, col 3; no bytes in silent mode.
- **Decoder on the real tty path (1.2).** Through `UnixTerminal.nextEvent` on the helper pty: `ESC [ 7 ; 3 R` produces **no event** (the decoder already drops a non-`1;m` `R`), while `ESC [ 1 ; 5 R` produces `key f3 ctrl`. So the ambiguity is real but narrow: it only affects a reply from row 1 with a column from 2 to 8, which is exactly when the "request outstanding" flag is needed. Without a request outstanding, no change in behavior is needed.
- **Latency and clamping on a real terminal (1.3).** iTerm2 (`TERM=xterm-256color`, no tmux, 53 rows): 10 of 10 requests answered, latency 0.3 ms to 16.2 ms. `CSI 999 B` left the cursor on row 53 (the last row) and `CSI 999 A` on row 1, so clamping works as the design assumes; the `pyte` emulator agrees (`CSI n B`, `CSI n A`, and a line feed on the last row all stay inside the screen). The pty helper answers in about 2 ms.
- **Timeout.** The worst measured reply is 16 ms, so 200 ms leaves more than ten times the margin for a slower path (ssh, a loaded machine) while a silent terminal still costs only 200 ms once. Keep 200 ms.
- **Not yet covered:** tmux, macOS Terminal, and a Linux terminal; these are checked in task 5.3.

## Decision

**Go** (confirmed by the maintainer after the spike). The cursor position query works on the real tty path and on iTerm2, the reply/key ambiguity is contained by the outstanding-request flag, and the 200 ms timeout is settled. A "no-go" would have meant dropping the query and falling back to anchoring without gap use (model B).

## Implementation notes

- With Ballerina 2201.14.2, after `terminal is term:CursorReporter` a method call directly on the narrowed value crashes the compiler (`Cannot read field "owner" because "symbol" is null`). Assigning it first (`term:CursorReporter reporter = terminal;`) and calling through `reporter` works. The renderer must do the same.
- The method is named `queryCursor` (not `cursorPosition`) because `FakeTerminal.cursorPosition()` already exists with a different return type; the record is `term:CursorPosition {row, col}`, counted from zero.
