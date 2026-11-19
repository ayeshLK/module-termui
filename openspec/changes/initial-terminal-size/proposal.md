# Proposal

## Why

A program cannot learn how wide the terminal is. It receives a `ResizeEvent` only after the window changes, so on its first `view` it has no size at all. Anything that lays out to the width (the line editor's `render(width)`, a table, a wrapped status line) has to guess; the agent harness passes 10000 to `LineEditor.render` and lets the terminal wrap. The runtime already knows the size it draws with, so the program should be told. It is additive and belongs before 1.0, since it fixes what a program may rely on at start.

## What Changes

- The runtime delivers the size it is using, as a `ResizeEvent`, to the program before any other message, and keeps delivering a `ResizeEvent` when the size changes (as today).
- The initial size is information only: it does not clear, redraw or move anything on the terminal, unlike a real resize.
- It applies in every mode: the size is the terminal's when it reports a usable one, and the fallback the runtime draws with otherwise (80 by 24), so the program and the renderer agree.
- The documentation tells programs that the first message is their size. The line editor's example and the harness use it (the harness once the release is out, since examples build against the published package).

## Capabilities

### New Capabilities

### Modified Capabilities
- `mvu-runtime`: a requirement that the size the runtime draws with is the first message a program receives.

## Impact

- `ballerina/engine.bal` (`launch`, `step`, `run`), docs (`Module.md`, `Package.md`, `Program.update`, the line editor's `Module.md`), tests in `ballerina/tests`.
- Programs that count or log every message will see one more at the start; programs that ignore unknown messages are unaffected.
- Follow-up after the release: `examples/agent-harness` passes the real width to `LineEditor.render` instead of 10000.
