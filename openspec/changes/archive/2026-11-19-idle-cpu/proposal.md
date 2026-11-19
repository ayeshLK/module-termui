# Proposal

## Why

A termui program that is waiting for a key uses about 10% of a CPU core and 74 to 98 MB of memory (measured on the counter example, against 0.1% and 22 MB for a Ballerina program that just sleeps). It writes nothing while idle: the cost is the loops that check for work. The engine loop wakes every 5 ms (`Options.pollInterval`) and the terminal's `nextEvent` wakes every 2 ms, so a program left open all day keeps a core partly awake. Ballerina has no way to wait for "input or a timer or a message", so the loops poll; they can at least poll less when nothing is happening.

## What Changes

- Both polling loops back off while idle: the time between checks grows from the base interval (5 ms for the engine loop, 2 ms for input) in stages up to a ceiling, and returns to the base on the first message or byte.
- New `Options.maxPollInterval` (default **0.5 s**): the ceiling for the engine loop. `UnixTerminal` takes the same setting for the input loop, and `Interface` passes one value to both. A value at or below the base interval turns the backoff off.
- `Options.pollInterval` is documented as the shortest time between checks, not a fixed one, so the loop may sleep longer when idle. The default (0.005) is unchanged.
- The queues' take-all operations stop copying when they are empty.
- Repeatable measurement scripts (`bench/idle_cpu.py`, `bench/latency.py`) and documented targets, so the effect is checked and stays checked.
- **Trade-off, accepted:** the first key after a long pause waits for the loops that are sleeping at the ceiling (two hops: input, then engine). With a 0.5 s ceiling that is about 0.5 s on average and up to about 1 s after more than roughly 13 s of idleness; after shorter pauses it is much less (see the design). Lowering `maxPollInterval` shortens it.

## Capabilities

### New Capabilities

### Modified Capabilities
- `mvu-runtime`: the engine loop backs off while idle, up to a configurable ceiling, and `pollInterval` is the shortest sleep.
- `terminal-backend`: the Unix terminal's wait for input backs off the same way.

## Impact

- `ballerina/engine.bal` (`Options`, `run`), `ballerina/queue.bal`, `ballerina/headless.bal` (`Interface`, `options()`), `ballerina/modules/term/unix.bal` and `input.bal`, tests in `ballerina/tests` and `ballerina/modules/term/tests`.
- Docs: `Module.md`, `Package.md`, `modules/term/Module.md`, README limits, `COMPATIBILITY.md` (the list of defaults), `CONTRIBUTING.md` (how to run the measurements).
- New `bench/` directory with the measurement scripts.
- No existing API changes: the new option and parameters have defaults, and the documented meaning of `pollInterval` is widened, which is why this goes in before 1.0.
- Not in this change: a blocking wake-up (named pipe) that would remove polling and the first-key delay altogether; it is the follow-up that makes a long ceiling free.
