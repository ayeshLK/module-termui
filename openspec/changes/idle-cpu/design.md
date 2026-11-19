# Design

## Context

See proposal.md. The idle cost comes from two sleep loops: `run` sleeps `pollInterval` (5 ms) between `step()` calls, and `UnixTerminal.nextEvent` sleeps 2 ms between checks of the byte queue (plus a once-a-second size check when the terminal sends no resize notifications). Measured on this machine over 20 s idle (percent of one core): Ballerina sleeping 0.1, one 5 ms loop 2.5, one 2 ms loop 4.0, both 5.4, counter example about 10; a modelled backoff to a 50 ms ceiling about 1.4, to 250 ms about 0.9 (the floor is the strands and the resize spawn). The path a key takes while idle is two sleeping hops: input loop (byte queue to message queue), then engine loop (message queue to `update`).

## Goals / Non-Goals

**Goals:**
- Idle CPU of a waiting program from about 10% to about 1 to 2%.
- A short pause costs little: the long ceiling is reached only after sustained idleness.
- No API break, no behaviour change while active, no lost messages.

**Non-Goals:**
- No blocking wake-up (named pipe). A spike showed it works (about 0.4% idle, 1 to 3 ms wake latency) and it is the way to a long ceiling with no first-key delay, but it touches the engine, `Session` and the terminal and has lifecycle risks; it is a separate change after this one.
- No change to the resize check interval (1 s), to frame coalescing, or to the renderer.

## Decisions

**1. Staged backoff, reset on activity.** The loop counts consecutive empty checks. After every 20 of them the interval doubles, up to the ceiling; any message (or byte) resets it to the base. With a 5 ms base the schedule is:

| Idle for about | Interval | First key waits (average, per hop) |
|---|---|---|
| under 0.1 s | 5 ms | 2.5 ms |
| up to 0.3 s | 10 ms | 5 ms |
| up to 0.7 s | 20 ms | 10 ms |
| up to 1.5 s | 40 ms | 20 ms |
| up to 3 s | 80 ms | 40 ms |
| up to 6 s | 160 ms | 80 ms |
| up to 13 s | 320 ms | 160 ms |
| beyond | 500 ms (the ceiling) | 250 ms |

The input loop (2 ms base) follows the same rule and reaches the ceiling after a similar time. For the engine loop "activity" means anything but a tick of the program's own `every` timers (found while implementing: the agent harness starts a 0.1 s timer for its spinner clock, which would otherwise reset the loop ten times a second and defeat the backoff). The engine remembers each timer's message and period, treats an equal message as a tick that does not reset the schedule, and lowers the ceiling to half the period of the fastest timer so the ticks are handled on time; the harness then idles at 50 ms. A key after a pause of a few seconds therefore costs tens of milliseconds, and only after more than about 13 s of nothing does it cost around half a second on average (two hops: up to about 1 s worst case). The staging is why the long ceiling is tolerable for typing bursts, and the measurements in task 5.2 record the real numbers.

**2. The schedule is a pure function.** `nextInterval(current, emptyChecks, base, ceiling)` returns the next interval and the new count; both loops call it. It is unit-tested without sleeping, and the loops only add the sleep. Alternative: write the logic inline twice; rejected because the two loops must stay consistent.

**3. Ceiling default 0.5 s, option `Options.maxPollInterval`.** Chosen by the maintainer for the lowest idle cost; the trade-off (first-key delay after a long pause) is accepted and documented. `UnixTerminal.init` gets an optional `maxPollInterval` (default 0.5) and `Interface` passes its own setting to the terminal it creates and to `options()`, so one number configures both loops. A ceiling at or below the base disables the backoff (and so restores the old behaviour exactly), which is also what a latency-sensitive program should choose if it wants no delay at all. Alternative: a separate option for each loop; rejected as noise for one concern.

The name is `maxPollInterval`, not `idlePollInterval` (renamed on the maintainer's suggestion): `idle...` reads as a fixed interval used while idle, whereas the loop adapts between `pollInterval` (the minimum) and `maxPollInterval` (the maximum), so the pair reads as the bounds.

**4. `pollInterval` keeps its default and becomes "the shortest sleep".** Only the doc sentence changes, so a later change to how long the loop sleeps when idle stays within what is documented. `COMPATIBILITY.md` lists the new default (`maxPollInterval` 0.5) with the others.

**5. The cursor position request does not depend on the idle loop.** `queryCursor` writes the request and then waits up to 200 ms for the reply, which today is decoded by `nextEvent` on the input strand. With that loop asleep at 0.5 s the reply could arrive after the timeout and anchoring would be switched off for the session. `queryCursor` instead runs the same locked "drain and decode" step in its own wait loop (it already polls every 2 ms), so the reply is found whatever the input loop is doing. Key events decoded that way go to the `ready` list and are delivered by `nextEvent` as usual. The lone-Escape timeout needs no change: any received byte resets the input loop to its base interval, so the 50 ms check is made at the fine granularity.

**6. Cheaper wakeups.** `MessageQueue.takeAll` and `ByteQueue.takeAll` clone their list twice even when it is empty; they return an empty list directly in that case. This lowers the cost of every remaining wakeup and the allocation that drove resident memory up.

**7. A tick that changes nothing does not redraw.** Measuring the effect on programs with a timer showed that backoff alone is not enough: a trivial program with a 100 ms timer still idled at about 8% (3% with a 0.5 s timer), because every handled message draws a frame, and a frame costs several milliseconds when the code runs only ten times a second and is not hot. The engine now remembers the last frame it drew and skips the draw when the step handled only timer ticks that returned no command and the new view equals it. Anything else (a key, an effect result, a resize, a question, the first frame, a tick that returned a command) still draws, so no behaviour changes; the comparison is a deep equality of the span lists, far cheaper than a draw.

**8. Measure it, repeatably.** `bench/idle_cpu.py` runs a built jar on a pseudo-terminal, lets it warm up, and reports CPU over a window, bytes written and RSS; `bench/latency.py` reports key to first output byte after short and long idle gaps. Targets: idle CPU under 3% for a program without a fast timer (the counter); a program with a timer idles higher, in proportion to its tick rate; the first key after a pause of up to a second at a median of about 50 ms or less; after a long pause no worse than about the ceiling. They are guidance, not a CI gate, because timing on shared runners is noisy.

## Risks / Trade-offs

- [First key after a long pause is slow with a 0.5 s ceiling] → staged schedule so short pauses are cheap, `maxPollInterval` to lower or disable it, documented in the README limits and the module pages, measured in task 5.2; the named-pipe follow-up removes it.
- [An effect result or a timer tick waits for a sleeping loop] → an effect result is a message like any other and waits up to the current interval (documented). A tick can be late by at most half its period, because the ceiling is lowered to that (see decision 1); a timer with a long period (seconds) can be late by up to the ceiling.
- [Timing-based tests become flaky] → the schedule is tested as a pure function; integration tests use small ceilings (50 to 100 ms) and generous margins.
- [The cursor report regression described in decision 5] → covered by a test that holds the input loop at its ceiling and then asks for the position.

## Open Questions

- Whether the once-a-second resize check should also stretch when idle (it is a separate spawn costing about 0.5% idle). Left alone here; can be a follow-up.

## Measured results (2026-11-19)

Before is termui 0.4.0 from Central, after is this change; the counter example and the agent harness on
macOS (M-series, JDK 25), `bench/idle_cpu.py` (4 to 15 s warm-up, 20 s window) and `bench/latency.py` (6 key
presses per gap, so the maxima are single samples and the figures are magnitudes).

| Program, idle | Before | After |
|---|---|---|
| Counter example (no timer) | 9.3% of a core, 79 MB | **1.1%**, 55 MB |
| Agent harness (a 10 Hz timer) | 12 to 16.5%, 142 to 192 MB | **7.0 to 7.6%**, 67 to 141 MB |
| Scratch program, 10 Hz timer, view never changes | 8.0 to 9.7%, 193 to 225 MB | 4.2%, 71 MB |

The counter meets the under-3% target. A program with a fast timer idles higher, because its own `update` and
`view` run at the timer's rate: halving the cost of the harness would need the harness to stop its timer while
idle (there is no way to cancel an `every` timer today). Skipping the redraw of an unchanged tick (decision 7)
removed most of the rest, and cut the allocation rate from about 20 MB/s to under 5 MB/s.

First key after an idle pause (counter example, key to first output byte, ms):

| Idle before the key | Before: p50 / max | After: p50 / max |
|---|---|---|
| 0.05 s | 13.6 / 39.5 | 18.9 / 112 |
| 1 s | 11.1 / 16.9 | 42.8 / 73 |
| 3 s | 10.4 / 12.6 | 112 / 196 |
| 15 s | 12.4 / 15.5 | **498 / 514** |

This is the accepted trade-off: the median first key is about 40 ms after one second of idleness, about 110 ms after
three seconds, and about half a second once both loops sit at the 0.5 s ceiling (after roughly 13 s). Lowering
`maxPollInterval` shortens it (a 100 ms ceiling would cap it at about 100 ms median). The named-pipe wake-up
follow-up removes it. The 112 ms maximum at a 0.05 s gap is a single outlier sample.

