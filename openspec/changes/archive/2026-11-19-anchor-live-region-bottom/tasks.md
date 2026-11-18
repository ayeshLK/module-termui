# Tasks

Group 1 is a gate: groups 2 onward build on its answers. If the cursor position query turns out to be unreliable, stop and revisit the design (the fallback is the simpler "anchor and leave commits unchanged" model, which the exploration judged visually worse).

## 1. Spike: the cursor position query (gate)

- [x] 1.1 Teach the pty test helper (`ballerina/tests/resources/pty_helper.py`) to answer a cursor position query (`ESC [ 6 n`) with a configured row and column, and to stay silent on request; verify with a small throwaway program that opens the helper's pty, sends the query, and reads back `ESC [ row ; col R` (and nothing in silent mode)
- [x] 1.2 In a throwaway program, send the query through the real tty path, read the reply from the input bytes, and check that the same bytes without an outstanding request decode as the Ctrl+F3 key; verify by recording the observed bytes and the decoder's output in `design.md` under "Spike results"
- [x] 1.3 Measure the answer latency with an answering terminal and the cost of a silent one (one timeout, then remembered), and check that `CSI n B` and `CSI n A` clamp at the last and first rows on the terminals available here; verify the numbers are recorded, and settle the timeout value
- [x] 1.4 Record a go or no-go in `design.md`, including what a "no-go" would change; verify it is reviewed before group 3 starts

## 2. Cursor position capability (`term` module)

- [x] 2.1 Add the `CursorReporter` object type and implement it on `FakeTerminal` from its virtual screen; verify unit tests for the position after plain output, after cursor moves, and after scrolling
- [x] 2.2 Make the input decoder recognize `CSI row ; col R` as a report only while a request is outstanding, and keep decoding the same bytes as a key otherwise; verify decoder unit tests for both cases (including that a report is consumed and produces no key event)
- [x] 2.3 Implement the query on `UnixTerminal` (write the request, wait for the reply on the existing input path with the timeout from the spike, remember an unsupported terminal); verify `tty`-group tests through the helper for an answering terminal, a silent terminal (a timeout once, then immediate), and that keys typed during the wait are not lost
- [x] 2.4 Document the capability in the `term` `Module.md` (optional interface, the timeout, that `nextEvent` must be running); verify the documented snippet compiles

## 3. Renderer: bottom anchoring (`render` module)

- [x] 3.1 Add the anchored state (anchored flag, gap, region height) and the first-draw positioning (clamped move to the last row, line feeds for the shortfall only, up by the region height minus one), used only when the terminal is a `CursorReporter` and the position is known; verify renderer tests on `FakeTerminal` for room below the output, a cursor near the bottom (the screen scrolls by exactly the shortfall and nothing is overwritten), a terminal that cannot report (output identical to unanchored), and the plain and full-screen cases (no effect)
- [x] 3.2 Diff the region aligned at its bottom row and let growth use the gap first; verify tests that a region growing within the gap grows upward with its bottom rows unchanged and nothing scrolls, and that growth beyond the gap scrolls only for the excess
- [x] 3.3 Make a shrinking region keep the last row and return its rows to the gap; verify tests that no blank row is left below the region and the vacated rows are blank above it
- [x] 3.4 Write committed output into the gap before scrolling, counting the rows a prose line occupies by simulating terminal wrapping and re-measuring the cursor after commits that contain wide or ambiguous-width characters; verify tests for a commit that fits, one longer than the gap (the rest scrolls), wrapped prose rows, and that no blank row ever reaches the scrollback
- [x] 3.5 Verify behavior once the gap is used up: a renderer test that keeps committing until the gap is gone and then further, asserting that the banner and earlier output are in the scrollback intact and the region stays on the last row
- [x] 3.6 Re-anchor after a resize (clear as today, forget the anchored state, query again at the next draw); verify tests on a reflowing and a non-reflowing fake terminal that no rows of the old region remain and the region is on the last rows of the new size
- [x] 3.7 Expose `anchorBottom` on `InlineRenderer.init` (default `false`) and document the model, the fallback, and the limits (no pinned header, needs a terminal that reports its cursor) in the `render` `Module.md`; verify the documented example compiles and a mutation of the gap arithmetic fails a test

## 4. Runtime plumbing

- [x] 4.1 Add `Options.anchorBottom` (default `false`) and pass it to the renderer that `run` creates; verify runtime tests on `FakeTerminal` that the default output is unchanged and that with the option on the first frame is on the last rows
- [x] 4.2 Add `anchorBottom` to `Interface.renderer` and `Interface.run`, ignored in the non-interactive modes; verify tests that plain, piped, and headless output is byte-identical with the option on and off
- [x] 4.3 Document the option in `Package.md` and the root `Module.md`; verify the documented snippets compile

## 5. Example, recording, and integration

- [x] 5.1 Turn the option on in `examples/agent-harness` and extend its pty check so the driver answers the cursor query and feeds the output to a terminal emulator (`pyte`), asserting that the input line is on the last row at the first frame and the banner is still on screen after the first turn; verify the check passes locally and add `pyte` to the CI step and `CONTRIBUTING.md`
- [x] 5.2 Re-record `docs/assets/harness-demo.gif` with the anchored input and check frames from the start, mid-answer, and the end for stray rows or a clipped banner; verify the frames by looking at them and update the README caption if needed
- [x] 5.3 Maintainer action: run the harness in at least two real terminals (for example macOS Terminal and iTerm2, or a Linux terminal) and in tmux, and record in `design.md` whether the cursor query is answered, whether anchoring looks right, and the scrollback after a long conversation; verify the notes are written
- [x] 5.4 Run the full default and `tty` suites and the harness check in CI on Linux and macOS; verify all are green

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Close issue #3 when the change is archived.
