# Tasks

## 1. The backoff schedule

- [x] 1.1 Add the pure function `nextInterval` (current interval, count of empty checks, base, ceiling) with the doubling-every-20-checks rule, reset-to-base and "ceiling at or below base means off"; verify with unit tests that follow the table in design.md, the cap, the reset and the disabled case

## 2. Engine loop

- [x] 2.1 Add `Options.maxPollInterval` (default 0.5) and use the schedule in `run`: a step that handled a message resets to `pollInterval`; verify with runtime tests that messages arriving during a long interval are all delivered in order, that the interval returns to the base after one, and that a ceiling at or below `pollInterval` behaves as before (use ceilings of 50 to 100 ms)
- [x] 2.2 Reword the `pollInterval` and `maxPollInterval` docs on `Options` ("the shortest sleep", "may sleep longer when idle") and set `maxPollInterval` from `Interface.options()`; verify the generated docs read correctly and the options-defaults test covers the new default

- [x] 2.3 Skip the draw when a step handled only timer ticks that returned no command and the view equals the last drawn frame; verify with tests using a counting renderer (a quiet tick draws nothing, a tick that changes the view draws, a key always draws) and that the existing runtime tests still pass

## 3. Input loop

- [x] 3.1 Factor the locked "take bytes, decode, accept" step of `UnixTerminal.nextEvent` into one function, use it from `nextEvent` with the schedule (base 2 ms, ceiling from a new optional `maxPollInterval` init parameter, default 0.5) and have `Interface` pass its setting; verify the existing terminal tests (decoder, unix, pty) still pass
- [x] 3.2 Make `queryCursor` call the same step in its own wait loop so the reply is found while the input loop is idle; verify with a test that holds the input loop at its ceiling and then requests the cursor position, and with the Escape-key and anchoring tests
- [x] 3.3 Add tests for the "Idle terminal" and "Input after a pause" scenarios (small ceiling, a key pushed after the loop has backed off arrives within about the ceiling and the loop is back to base afterwards)

## 4. Cheaper wakeups

- [x] 4.1 Return an empty list without cloning from `MessageQueue.takeAll` and `ByteQueue.takeAll` when nothing is queued; verify with the existing queue tests and a test that an empty take does not allocate a new list for the queue's own state

## 5. Measurement and documentation

- [x] 5.1 Add `bench/idle_cpu.py` and `bench/latency.py` (pseudo-terminal harness, warm-up, CPU over a window, bytes and RSS; first-output latency after short and long gaps) and a short `bench/README.md`; verify they run against the counter example and the harness
- [x] 5.2 Run them before and after the change on the counter and the harness, record the numbers and the first-key latency by idle duration in design.md, and check the targets (idle under 3% for a program without a fast timer, median first key about 50 ms or less after a pause of up to a second)
- [x] 5.3 Document the backoff, the new option, its default and the first-key trade-off in `Module.md`, `Package.md`, `modules/term/Module.md` and the README limits, add `maxPollInterval` to the defaults in `COMPATIBILITY.md` and the changelog's Unreleased section, and describe the measurements in `CONTRIBUTING.md`; verify the pages agree and `bal doc` has no warnings
- [x] 5.4 Run the whole suite, the harness check on the pty and the tmux check script; verify all pass and CI is green on Linux and macOS

## Workflow follow-up

- Include in the next release (the user does this), then archive the change.
- Follow-up change after this one: the blocking wake-up (named pipe) behind an internal waker, falling back to this backoff.
