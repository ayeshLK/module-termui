# Design

## Context

See proposal.md. `run` already works out the size it draws with (`usableSize(terminal.size(), 80x24)`) and hands it to the renderer; the engine only reacts to `ResizeEvent`s that arrive through the queue later, calling `Renderer.resize` for each. The runtime therefore knows the size and never tells the program.

## Goals / Non-Goals

**Goals:**
- The program knows the width from the first message and the first view.
- The delivered size and the renderer's size are the same value.

**Non-Goals:**
- No new message type: the existing `term:ResizeEvent` carries it, so programs that already handle resizes need no new branch.
- No size query for effects (`Session` stays as it is); an effect that needs the width can be sent it in a message.
- No change to how later resizes are detected.

## Decisions

**1. Deliver from the engine's first step, not through the queue.** `launch(initial, size)` remembers the size, and the first `step` calls `program.update` with it before the initial command and before draining the queue. Putting it in the queue instead would let a key arriving at the same time overtake it, and would run it through the resize path that clears and redraws the live region. Calling the program directly gives both the ordering and the "no terminal output" guarantee, and the first frame is drawn after the update as usual.

**2. The size is whatever `run` gave the renderer.** `run` passes the same `usableSize` result to the renderer and to `launch`, so a pseudo-terminal nobody sized (0 by 0) delivers 80 by 24 and the program lays out to what is drawn. `Interface.run` goes through `run`, so headless and piped modes are covered; only direct `Engine` use in tests can skip it.

**3. The fallback is an option.** `Options.fallbackSize` (default 80 by 24) replaces the size that was hard-coded in `run`, and `Interface.options()` sets it from the environment (`COLUMNS`, `LINES`). Without it, an interface on an unsized terminal would draw with the environment's size but tell the program 80 by 24. Found while testing; it is one additive field.

**4. The program's returned command is carried out like any other.** A program may react to its size by returning a command (rare, but nothing special is needed).

**5. Documentation and the line editor.** `Program.update` and the module pages say the first message is the size. The line editor's `Module.md` example keeps the width from that message and passes it to `render`. The harness switches too, but after the release, per the examples rule.

## Risks / Trade-offs

- [A program that asserts on its exact message list sees one more message] → additive, noted in the changelog and release notes; programs ignoring unknown messages are unaffected.
- [Programs that assumed no resize event until the window changes] → the event type is the same, and a program that redraws on resize now also draws at startup, which is the intent.
- [A terminal that cannot report its size] → the fallback is delivered, as documented, so the program is never left without a number.
