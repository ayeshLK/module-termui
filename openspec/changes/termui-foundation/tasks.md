# Tasks

Depends on `termui-scaffold` for the build, test, and CI setup. Group 1 is a gate: groups 2 onward are built on its answers.

## 1. Spike (gate)

- [x] 1.1 In a throwaway program, enter raw mode with `stty` on `/dev/tty`, read raw bytes through a byte channel, and test `min 0 time 1` for a lone Esc versus an arrow-key sequence; verify the result (works, or zero-byte read treated as end of input) is written under "Spike results" in `design.md`
- [x] 1.2 Test whether a blocking tty read on a strand starves other strands (a ticker strand keeps running during a blocked read) and whether the reader needs a dedicated thread; verify the ticker's observed cadence is recorded in `design.md`
- [x] 1.3 Test whether the compiler enforces `isolated` on a `start`ed effect function and on posting a mutable message, or only hints; verify with a compile of both a correct and an offending sample and record the diagnostics
- [x] 1.4 Test whether `runtime:onGracefulStop` fires on SIGINT and SIGTERM while the terminal is in raw mode and can restore it; verify by sending both signals to a running sample and recording the terminal state afterward
- [x] 1.5 Measure write throughput and flicker for writing a full frame in one flushed write at streaming rates, and measure hello-world startup and time-to-first-frame on the JVM; verify the numbers are recorded and use them to propose a startup budget in `design.md`
- [x] 1.6 Record a go or no-go for the pure-Ballerina Unix backend in `design.md`, with the JLine-shim fallback noted for any failed question; verify the decision is reviewed before group 3 starts

## 2. Text primitives (`text` module)

- [x] 2.1 Implement styled text (colors, attributes, spans) with the color-disabled path, and verify unit tests cover mixed-style lines and `NO_COLOR` output
- [x] 2.2 Implement display width (wide characters, combining marks, escape sequences counting zero) with static range tables (small literals, so no lazy build is needed), and verify unit tests cover CJK, combining marks, and ANSI strings
- [x] 2.3 Implement wrapping (word boundaries, overlong-word split, style continuity, hanging indents), and verify unit tests cover every scenario in `specs/text-primitives/spec.md`
- [x] 2.4 Document the module in `Module.md` with a short example, and verify the example compiles and its output matches the docs

## 3. Terminal abstraction and fake backend (`term` module)

- [x] 3.1 Define the `Terminal` interface (acquire, release, read events, size, write frame) and the input event types, and verify the module compiles and an interface-conformance test passes for the fake backend
- [x] 3.2 Implement the in-memory fake backend with scripted input and screen inspection, and verify tests feed a key sequence and read back rendered contents
- [x] 3.3 Implement environment detection (stdin/stdout tty checks, `NO_COLOR`, `TERM=dumb`, default width), and verify tests with redirected stdio and environment variables cover each scenario in `specs/terminal-backend/spec.md`

## 4. Unix backend (`term` module)

- [x] 4.1 Implement raw-mode acquire and restore with `stty`, including restore on release, catchable errors, and graceful stop, and verify `tty`-group tests (a helper-owned pty, no controlling terminal needed) confirm the settings are restored on release and when the work fails; restoring on a real signal is verified in 8.1 with the example app, since the spike (1.4) showed the graceful-stop hook fires and the hook calls the tested `release`
- [x] 4.2 Implement the key and paste decoder (printable, arrows, navigation, function keys, Ctrl and Alt, lone Esc via a decoder-level timeout, bracketed paste, sequences split across reads), and verify decoder unit tests on byte sequences plus a `tty`-group test through a pty
- [x] 4.3 Implement terminal size query and resize detection (polling, plus DEC mode 2048 where supported), and verify a `tty`-group test changes the pty size and sees a resize event
- [x] 4.4 Implement single-call frame output for the Unix backend, and verify through the helper pty that large frames arrive complete and in order and that throughput is well above 60 frames per second; that the renderer issues exactly one `write` per frame is verified in 5.1 with the fake terminal's write log
- [x] 4.5 Document the backend's requirements and limits (Unix only, `stty sane` recovery after a hard kill) in `Module.md`, and verify the documented recovery command restores a raw terminal

## 5. Renderer (`render` module)

- [x] 5.1 Implement the cell buffer and frame diffing, and verify tests that an unchanged frame writes nothing and a one-cell change writes only that cell
- [x] 5.2 Implement the inline viewport with variable region height, and verify tests on the fake backend that earlier content is untouched and no leftover rows remain after growing and shrinking
- [x] 5.3 Implement commit-above, with prose written as logical lines and structured blocks pre-wrapped, and verify tests show committed output above the live region and never redrawn
- [x] 5.4 Implement resize handling (compute the rows the old region now occupies, clear, and redraw), and verify fake-backend tests simulating reflowing and non-reflowing terminals leave no stale rows when narrowing and widening
- [x] 5.5 Implement alternate-screen mode, and verify a test that entering and leaving restores prior contents
- [x] 5.6 Implement the plain renderer and the testable-frame inspection, and verify tests that piped output has no escape sequences, spinners are not repeated, and a test can assert on text and styles
- [x] 5.7 Document the renderer (live region, commit-above, resize behavior and its limits) in `Module.md`, and verify the documented snippets compile

## 6. MVU runtime (root module)

- [x] 6.1 Implement the lock-guarded event queue behind a small interface, and verify tests for ordered delivery and no dropped messages from concurrent producers
- [x] 6.2 Implement the single-owner loop with update, view, and frame coalescing, and verify a test applying fifty queued messages draws exactly one frame
- [x] 6.3 Implement effects that return messages (including streaming effects) with `readonly` messages and `isolated` effect functions, applying the spike's isolation findings, and verify tests that results arrive as messages and a mutable post is rejected
- [x] 6.4 Implement input, resize, and tick message sources, and verify a test shows keystrokes are delivered while a long effect runs
- [x] 6.5 Implement clean shutdown (stop sources, release the terminal, no further messages), and verify a test that quitting restores the terminal and stops delivery
- [x] 6.6 Implement the blocking `confirm` and `select` prompts over the loop, and verify scripted-input tests return the answer and clear the prompt from the live region
- [x] 6.7 Document the runtime (message loop, ownership rule, effects, prompts) in `Module.md` with a counter-style example, and verify the example runs against the fake backend as documented

## 7. Headless behavior

- [x] 7.1 Implement mode selection from stdin and stdout tty state across all four combinations, and verify tests for each combination choose the expected mode
- [x] 7.2 Route the interactive interface to the tty (or stderr) and results to stdout when stdout is redirected, and verify a test captures stdout and finds only result output
- [x] 7.3 Implement `NoTerminal` errors and caller-supplied defaults for prompts without a terminal, and verify tests that a prompt returns immediately with the error or the default and never blocks
- [x] 7.4 Verify headless output is deterministic and wraps at 80 columns when width is unknown, using a repeated-run byte-comparison test
- [x] 7.5 Document headless behavior and the stdout/tty split in `Package.md`, and verify the documented commands produce the documented output

## 8. Integration and delivery

- [ ] 8.1 Build an `examples/` app that streams text, shows a live region, and asks an approval prompt, and verify it runs interactively and headless (piped) with the documented behavior, and that SIGTERM and SIGINT sent to it under a pty leave the terminal restored
- [ ] 8.2 Run the native-image check from `termui-scaffold` (`bal test --graalvm`) and also build the example with `bal build --graalvm`, and record the result (pass or the first failure) in `design.md`; verify the outcome is reported without gating the build
- [ ] 8.3 Re-measure startup and time-to-first-frame on the finished foundation and compare with the spike baseline, and verify the numbers are recorded and the startup budget in `design.md` is updated
- [ ] 8.4 Run the full default and `tty` test suites in CI on Linux and macOS, and verify both are green

## Workflow follow-up

- Archive the change after the project's review requirements are satisfied.
- Verify the archived specs.
