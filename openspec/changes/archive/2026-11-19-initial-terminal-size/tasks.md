# Tasks

## 1. Runtime

- [x] 1.1 Deliver the size from the engine: `launch` takes the size, the first `step` hands it to `program.update` before the initial command and the queue, and `run` passes the size it gave the renderer; verify with runtime tests for the "First message" and "Later changes" scenarios (first message is the resize, before a key pushed at the same time)
- [x] 1.2 Test the fallback and the quiet delivery: a terminal that reports 0 by 0 (and one that errors) delivers 80 by 24, and delivering the initial size writes nothing to the terminal beyond the first frame; verify with tests on `FakeTerminal` and the headless `Interface` (output redirected and no terminal)
- [x] 1.3 Run the whole suite and fix tests that assumed no message before the first key; verify `./gradlew test` passes in all modules

## 2. Documentation

- [x] 2.1 Document the first message in `Program.update`, the root `Module.md` and `Package.md`, and update the line editor's `Module.md` example and its mirrored test to keep the width from that message; verify the doc test passes and the pages agree

## 3. After the release

- [x] 3.1 Once the release is published, change `examples/agent-harness` to pass the real width to `LineEditor.render` (remove `NO_WRAP`), extend `verify.py` to check that long input wraps with an indented continuation row, and bump the examples' pin; verify with `verify.py` on the pty

## Workflow follow-up

- Release with the next minor version (the user does this), then archive the change.
