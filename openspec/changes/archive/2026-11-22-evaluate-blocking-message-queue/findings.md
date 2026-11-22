# Findings

Measurements for `evaluate-blocking-message-queue`. Criteria and method are in `design.md`; the harness is
`bench/blocking-queue-eval/`. Machine: macOS (Darwin 23.4.0), Ballerina 2201.14.2, GraalVM CE JDK 25.0.5, laptop with
other applications open, so read figures as magnitudes.

## 1. Baseline cross-check (task 1.3)

The harness's `poll` strategy is compared with the existing benches on the counter example, which runs the same
backoff inside the real runtime.

| | `bench/` on `examples/counter` | harness `poll` |
|---|---|---|
| Idle CPU (16 s warm-up, 20 s window) | 0.49 s, 2.5% of one core | 0.10 s, 0.50% of one core |
| First key after 1 s idle: p50 / p90 or p95 / max | 56.9 / 228.7 / 228.7 ms (n=8) | 14.8 / 35.3 / 35.3 ms (n=8) |
| First key after 10 s idle: p50 / p90 or p95 / max | 208.5 / 527.8 / 527.8 ms (n=8) | 299.0 / 304.1 / 304.1 ms (n=8) |

Reading: the shapes agree and the figures are within the same order of magnitude, with the harness lower on idle CPU
and on the 1 s gap and the same size at 10 s (a consumer asleep at the 320 ms step wakes up to 320 ms late, which the
harness reproduces: its p95 is 304 ms). The harness is lower where it should be: it measures only the message-queue
wait, while the counter example also polls the terminal's input (its own backoff and a size query about once a
second) and draws a frame. Consequences for the rest of this document:

- Absolute figures for `poll` are a lower bound for what a real program spends; ratios between strategies describe the
  queue layer only.
- The idle-CPU criterion ("at most a third of the baseline's") is judged against the harness baseline (0.5%), which is
  the harder bar, because it excludes the input layer that a pipe strategy would not remove.
- Single runs of the idle CPU measurement vary by tens of percent on this machine; the idle figures for the decision
  are taken from three runs each (section 2).

The baseline is accepted as a fair comparison for the queue layer.

## 2. Wake latency and idle CPU (task 2.3)

Wake latency: a consumer is already waiting when the gap starts; a message is pushed after the gap; the time until the
consumer has taken it is recorded. 30 samples per cell. Times in ms.

| strategy | gap | n | p50 | p95 | max |
|---|---|---|---|---|---|
| `poll` | 0.1 s | 30 | 4.2 | 6.5 | 13.2 |
| `poll` | 1 s | 30 | 6.9 | 10.5 | 11.0 |
| `poll` | 3 s | 30 | 40.8 | 49.9 | 52.6 |
| `poll` | 10 s | 30 | 277.2 | 282.6 | 284.0 |
| `pipe-queue` | 0.1 s | 30 | 1.8 | 3.6 | 11.2 |
| `pipe-queue` | 1 s | 30 | 2.5 | 2.8 | 3.0 |
| `pipe-queue` | 3 s | 30 | 2.4 | 2.8 | 2.8 |
| `pipe-queue` | 10 s | 30 | 3.0 | 3.7 | 27.9 |
| `pipe-bell` | 0.1 s | 30 | 1.8 | 3.1 | 6.5 |
| `pipe-bell` | 1 s | 30 | 1.9 | 2.1 | 2.2 |
| `pipe-bell` | 3 s | 30 | 1.8 | 2.2 | 3.3 |
| `pipe-bell` | 10 s | 30 | 1.5 | 1.9 | 2.0 |

Notes on `pipe-queue`:

- In the first full run, the 10 s cell did not complete: a consumer waiting with a 40 s timeout reported "timed out
  waiting for the message" for a message pushed at 10 s. The 10 s row above is the first of two repeats (n=30 each);
  the second gave p50 3.0 / p95 3.4 / max 25.0 ms. The timeout did not recur in those 60 samples, nor in 18 more from
  short runs. **It is an unexplained anomaly with one occurrence in about 150 timed samples**, not an explained fault.
- The 10 s row shows an outlier of 25-28 ms in each repeat (and about 30 ms in the three 6-sample runs), once per run.
  It does not affect the p95 criterion (5 ms) but is not seen with `pipe-bell`.

Idle CPU: warm-up 16 s, window 60 s, three runs each, percent of one core.

| strategy | run 1 | run 2 | run 3 | mean | vs `poll` |
|---|---|---|---|---|---|
| `poll` | 0.75 | 0.73 | 0.72 | 0.73 | 1.00 |
| `pipe-queue` | 0.02 | 0.03 | 0.03 | 0.027 | 0.04 |
| `pipe-bell` | 0.03 | 0.02 | 0.02 | 0.023 | 0.03 |

Both pipe strategies pass the idle CPU criterion (at most a third of baseline) and the wake-latency criterion (p95 at
most 5 ms after a 10 s gap) at the queue layer. Keys still arrive through the terminal's polled input, which none of
these strategies changes, so this is not the user-visible gain.

## 3. Correctness stress (tasks 5.1 and 5.2)

Check: 8 producers on separate strands send numbered messages; the consumer verifies every message arrives exactly once
and in each producer's order. The check was shown to fail: the `broken` strategy (drops every 1000th message) failed
3 of 3 runs, with 1135, 2051 and 2655 lost messages and the same number of reorderings.

Short variant, 2 s per run: wait mode (consumer blocks in `waitForWork`) 100 runs, spin mode (tight `takeAll` loop,
maximum empty drains) 20 runs.

| strategy | wait runs | spin runs | failed runs |
|---|---|---|---|
| `poll` | 100 | 20 | 0 |
| `pipe-queue` | 100 | 20 | 0 |
| `pipe-bell` | 100 | 20 | 0 |

Long variant, 600 s, wait mode, one run per cell. Loaded means 22 busy `yes` processes on 11 cores, as in
`bench/stress_tests.sh`.

| strategy | idle machine | loaded machine |
|---|---|---|
| `poll` | pass: 827,581,490 sent = received, 0 lost, 0 reordered, 0 exceptions | pass: 321,229,526, 0 lost |
| `pipe-queue` | **hang** (no result within 660 s) | **hang** |
| `pipe-bell` | pass: 725,909,890, 0 lost | pass: 145,949,706, 0 lost |

### The `pipe-queue` hang is memory exhaustion

A 120 s `pipe-queue` run did not finish in 170 s. Sampling a running process (`jcmd GC.heap_info`,
`GC.class_histogram`):

| time into the run | heap used | live `Numbered` records |
|---|---|---|
| 15 s | not sampled | 2.76 million |
| 20 s | 3.3 GB | 3.86 million |
| 40 s | 4.67 GB (maximum 4.72 GB) | 7.56 million |
| 90 s | 4.71 GB | 7.96 million |

- The pipe is bounded at 1024 and its own objects are not the cause: one `Pipe`, 8 `Callback`, 5 `Observable`, one
  `TimerTask` array.
- The live records are Ballerina runtime objects: one `MapValueImpl` and one `BMapType` per live message, with
  per-type semtype objects and weak-map entries. After 15 s the count of live records (2.76 million) is about the
  number of messages sent so far, so essentially every message that passes through the pipe stays reachable. The
  consumer then stops making progress while the garbage collector runs (about 45 s of CPU on every GC thread in a 173 s
  process), which the watchdog reports as a hang.
- **Cause not identified.** What is ruled out: it is not the harness (`poll` and `pipe-bell` run the same producers and
  the same fresh `Numbered` records for 725 to 827 million messages without growth) and it is not a plain per-consume
  leak (section 5: 100,000 sequential produce/consume pairs of fresh records leave the heap at 6.8 MB, like `poll`).
  What it needs is the stress shape: 8 concurrent producers keeping the bounded pipe full, with blocked producers and a
  consumer that alternates `consume` and `consume(0)` timeouts. Finding the retaining reference needs a heap dump and
  is not done here; the finding is the behaviour, not its cause.
- Magnitude: about 3.9 million retained messages after 20 s, so on the order of a kilobyte per message. A termui
  program sends far fewer messages than the stress test, but the cost is unbounded growth per message.

`pipe-queue` fails the correctness criterion (zero hangs): both long runs hung and the leak was reproduced on the first
attempt with a 120 s run.

## 4. Throughput and drain cost (task 4.1)

Throughput: producers push `KeyEvent` messages as fast as they can while the consumer drains; messages per second.
First pass, 200,000 messages (a run of 0.09 to 1.4 s, so JIT warm-up and noise are large):

| strategy | 1 producer | 4 producers | 8 producers |
|---|---|---|---|
| `poll` | 2,245,662 | 1,303,082 | 1,300,350 |
| `pipe-queue` | 208,480 | 144,857 | 141,082 |
| `pipe-bell` | 775,437 | 808,276 | 896,884 |

The one-producer case decides the criterion, so it was repeated with longer runs (2,000,000 messages; 400,000 for
`pipe-queue`, which is much slower), three times each:

| strategy | run 1 | run 2 | run 3 | share of `poll` (median) |
|---|---|---|---|---|
| `poll` | 6,737,649 | 6,866,796 | 7,100,964 | 100% |
| `pipe-bell` | 1,602,142 | 2,191,047 | 2,226,905 | 32% (range 23% to 32%) |
| `pipe-queue` | 238,562 | 239,376 | 238,053 | 3.5% |

Both pipe strategies are below the 50% criterion at one producer. In absolute terms `pipe-bell` still moves about two
million messages a second, far more than a terminal program produces, so this is a failed criterion, not a practical
limit; the criterion was fixed in advance and is applied as written.

Drain cost, microseconds per `takeAll` (median / p95), by number of messages waiting:

| strategy | empty (0) | 1 | 50 | 1000 |
|---|---|---|---|---|
| `poll` | 1.6 / 7.0 | 5.8 / 13.1 | 7.2 / 9.8 | 33.4 / 43.0 |
| `pipe-queue` | 22.0 / 69.2 | 26.2 / 47.2 | 200.5 / 242.3 | 1026.5 / 1190.4 |
| `pipe-bell` | 1.6 / 6.5 | 5.0 / 11.8 | 5.9 / 9.0 | 38.5 / 47.3 |

Empty-drain median: `poll` 1.6 us, `pipe-queue` 22.0 us, `pipe-bell` 1.6 us. All are far below the 1 ms criterion.
`pipe-queue` is 30 times slower than `poll` at 1000 waiting messages, because every message is a separate `consume`.

## 5. Timer-task and message retention (task 4.2)

100,000 successful consumes (the message is pushed, `waitForWork(0.5)` returns it, `takeAll` drains it), then a
full-GC class histogram of the live process (`retention.py`, which uses `jcmd GC.class_histogram`):

| strategy | message | live heap after | live pipe `Callback` | live `TimerTask` | live `Observable` | live message maps |
|---|---|---|---|---|---|---|
| `poll` | same value | 6.45 MB | 0 | 0 | 0 | 44 |
| `pipe-queue` | same value | 6.67 MB | 0 | 0 | 5 | 72 |
| `pipe-bell` | same value | 6.59 MB | 0 | 0 | 5 | 67 |
| `poll` | fresh record each time | 6.57 MB | 0 | 0 | 0 | 48 |
| `pipe-queue` | fresh record each time | 6.80 MB | 0 | 0 | 5 | 76 |

Timer tasks are not retained after successful timed consumes, and the pipe holds nothing per operation: the suspicion
from reading the library's source is not borne out in this pattern. Cost per operation: `poll` 3.0 us, `pipe-bell`
2.8 us, `pipe-queue` 16.0 us. The memory growth in section 3 is therefore not this pattern; it appears only under the
concurrent stress shape.

## 6. Shutdown (task 4.3)

`close` while one consumer is blocked in `waitForWork(-1)`, and while 8 producers are blocked pushing to a full queue
(capacity 1024; `poll` and `pipe-bell` have no bound, so their producers never block):

| strategy | consumer returned after close | producers blocked at close | slowest producer return | outcome |
|---|---|---|---|---|
| `poll` | 6.9 ms (closed) | 0 | n/a | no hang, no exception |
| `pipe-queue` | 6.7 ms (closed) | 8 | 3.8 ms | no hang, no exception; all 8 returned |
| `pipe-bell` | 8.3 ms (closed) | 0 | n/a | no hang, no exception |

Shutdown is not a problem for any strategy. (The consumer return time for `poll` includes up to one backoff step, since
it notices `close` on its next check.)

## 7. JDK control: `java.util.concurrent.LinkedBlockingQueue` (tasks 3.1 and 3.2)

Implemented through `jballerina.java` interop with no Java code of our own (`jdk_queue.bal`); it passes the smoke test
with all three message shapes. The JDK queue has no `close`, so `close` puts a marker message that wakes every waiter.

A defect in my first version of the wrapper is part of the record: `waitForWork` sliced every wait into 1 s polls, so
an idle consumer woke once a second. Idle CPU was 0.30, 0.28, 0.28% (about 40% of `poll`, which would fail the
one-third criterion). The marker already wakes waiters, so the slicing was unnecessary; it was removed and the affected
measurements were repeated (the figures below are from the fixed wrapper unless stated). No criterion was changed.

Wake latency (n=30 per cell, ms), same method as section 2:

| gap | p50 | p95 | max |
|---|---|---|---|
| 0.1 s | 1.3 | 2.1 | 10.9 |
| 1 s | 1.9 | 2.1 | 2.2 |
| 3 s | 1.7 | 1.9 | 2.0 |
| 10 s | 1.6 | 2.0 | 2.0 |

Idle CPU (same method): 0.03, 0.03, 0.03% of one core, about 4% of `poll`.

Throughput at one producer (2,000,000 key messages, three runs): 3,675,194 / 4,140,662 / 3,864,600 per second, median
56% of `poll`'s 6.87 million (a narrow pass of the 50% criterion). At 200,000 messages: 1.53 / 1.56 / 1.57 million per
second with 1 / 4 / 8 producers.

Drain (us, median / p95): empty 3.2 / 18.0; 1 message 10.0 / 28.6; 50 messages 46.3 / 59.5; 1000 messages 442.0 / 635.5.
The JDK queue is drained one message per call through the interop, which is why a 1000-message drain is about 13 times
`poll`'s.

Shutdown: the blocked consumer returned 14.1 ms after `close`; the queue is unbounded, so no producer blocks.

Stress: short variant 100 wait-mode and 20 spin-mode runs, 0 failed. Long variant, 600 s, wait mode:

| condition | result |
|---|---|
| idle machine | pass: 729,838,443 sent = received, 0 lost, 0 reordered, 0 exceptions |
| loaded (22 busy processes) | **`OutOfMemoryError`**, twice: once on a 2 GB heap (an unfair setting that was my script's, since the other strategies ran on the default) and once on the default heap |

The loaded failure is a growing backlog, not a loss: sampling a loaded 120 s run showed 3.3 million `LinkedBlockingQueue`
nodes after 20 s and 3.7 million after 45 s, with 8.7 to 9.6 million live message maps and the heap at its 4.5 GB
limit. The producers (8 strands that sleep 0.1 ms every 64 messages) outrun a starved consumer that drains one message
per call, while `poll` and `pipe-bell` drain with a single list swap and survive the same flood. A terminal program
never sends messages at this rate, but the criterion allows no exceptions, so it is applied as written: **`jdk` fails
correctness under load.**

## 8. Build effect (task 6.1)

Each case was built as a throwaway library package with `bal pack` (2201.14.2, JDK 25) to read the platform out of the
`.bala` name, which is where Ballerina records it:

| case | resulting package | platform-specific? |
|---|---|---|
| no native dependency (control) | `ayesha-plainlib-any-0.1.0.bala` | no |
| depends on `xlibb/pipe` 1.6.1 (`pipe-queue`, `pipe-bell`) | `ayesha-pipelib-any-0.1.0.bala` | no, but it pulls `xlibb/pipe`, which is `java21` with one native jar (`platform/java21/pipe-native-1.6.1.jar`) |
| calls JDK classes through `jballerina.java` (`jdk`) | `ayesha-jdklib-java25-0.1.0.bala` | **yes: tagged with the JDK that built it** |

So adopting `pipe` leaves termui's own package platform-neutral but adds a `java21` dependency and a third-party
package that is a maintenance and trust cost (last release 2025-03-19). Adopting direct JDK interop would make termui's
package `java<N>`-tagged, which is a distribution cost that the package does not have today.

## 9. Conclusion (tasks 6.2 and 6.3)

### Criteria were not moved

`design.md` was last modified at 10:06 on 2026-11-22, the same minute as `proposal.md` and before the first
measurement, and was not edited afterwards. The change directory is untracked in git, so there is no commit to diff it
against; this statement rests on the file's modification time and on my own record of the session. The thresholds
applied below are the ones written there. Two things that look like adjustments are measurement fixes, not criteria
changes, and are recorded where they happened: the longer one-producer throughput runs (section 4) and the removal of
the 1 s wait slicing from the `jdk` wrapper (section 7).

### Every criterion against every strategy

| criterion (from `design.md`) | `poll` (baseline) | `pipe-queue` | `pipe-bell` | `jdk` |
|---|---|---|---|---|
| Correctness: zero loss, duplicate, reorder, exception or hang (stress, shutdown) | pass (0 failed of 120 short runs; 600 s idle 827,581,490 msgs and loaded 321,229,526 msgs, 0 lost) | **FAIL**: hung in both 600 s runs (idle, loaded); memory exhausted; plus one unexplained wake timeout | pass (0 of 120; 725,909,890 idle and 145,949,706 loaded, 0 lost) | **FAIL**: `OutOfMemoryError` in the 600 s loaded run (backlog), twice; idle run and short runs pass |
| Latency: p95 after 10 s gap at most 5 ms | 282.6 ms (the problem being solved) | pass: 3.7 ms | pass: 1.9 ms | pass: 2.0 ms |
| Idle CPU at most a third of baseline | 0.73% (baseline) | pass: 0.027% (4%) | pass: 0.023% (3%) | pass: 0.03% (4%) |
| Throughput at one producer at least 50% of baseline | 6.87 M/s (baseline) | **FAIL**: 239 k/s (3.5%) | **FAIL**: 1.6-2.2 M/s (23-32%) | pass: 3.7-4.1 M/s (56%) |
| Empty drain at most 1 ms at the median | pass: 1.6 us | pass: 22.0 us | pass: 1.6 us | pass: 3.2 us |
| Build: not platform-specific | pass (`any`) | pass (`any`), but adds a `java21` dependency | pass (`any`), same dependency | **FAIL**: `java25`-tagged bala |

No strategy passes every criterion. By the rule in `design.md` ("if none passes, recommend keeping the polling
backoff") and by the maintainer's stated rule for this change (keep the current implementation if there is no
significant gain), the recommendation is below.

### Recommendation: keep the polling backoff

- `pipe-queue`, the straightforward adoption, is not safe: it exhausted memory and stalled under the stress shape in
  both 10-minute runs, it is 30 times slower to drain 1000 waiting messages, and it had an unexplained missed wake-up
  once in about 150 timed samples.
- `pipe-bell` is the best candidate: correct in every run, wake p95 under 2 ms, idle CPU about 3% of the baseline. It
  fails one criterion, throughput at one producer (23-32% against 50%), while still moving about two million messages a
  second, far more than a terminal program sends. It is the only strategy that would be "viable except for one
  criterion", and relaxing that criterion would be the maintainer's decision, not this evaluation's; it was fixed
  beforehand and is applied as written.
- `jdk` is correct at normal rates but its unbounded queue ran out of memory when the consumer was starved under load,
  and it would make the package `java<N>`-tagged.

### The gain is small at the program level, which supports the same answer

These strategies change only how the engine waits for its message queue. The queue-layer measurements are
0.73% idle CPU and a 283 ms p95 wake after 10 s for polling. A real program also polls the terminal's input (its own
backoff plus a size query about once a second) and draws frames: the counter example idled at 2.5% of a core in the
baseline cross-check (section 1), against 0.50% for the queue layer in the same comparison. So the queue wait is at most
a quarter to a third of a program's idle CPU, and the best candidate would take about 2.5% to about 1.8-2.0% (an
estimate from those recorded numbers, not an end-to-end measurement; none was made, because changing `ballerina/` is out
of scope and no strategy passed). The delay before the first key after idleness depends on the input path as well,
which none of the strategies changes. A significant user-visible gain is therefore not demonstrated.

### What was learned (for the record)

- `xlibb/pipe` 1.6.1 resolves and runs on Ballerina 2201.14.2 with JDK 25. Timeout-0 drains return the documented
  timeout error; they are cheap when idle (22 us) and 30 times slower than a list swap at 1000 waiting messages.
- Used as the queue under 8 concurrent producers, it showed memory growth of the order of a message per message sent,
  until the heap filled; the cause is not identified (it is not the per-consume value conversion, which a sequential
  100,000-message test ruled out) and would need a heap dump. A single missed wake-up was seen once. Both are worth an
  upstream issue to `xlibb/module-pipe` with the harness as the reproduction; neither is pursued here.
- The timer-task retention suspected from reading the pipe's source was not found: no `TimerTask`, no `Callback` and no
  message was retained after 100,000 successful timed consumes (6.8 MB heap, as with `poll`).
- The wake-up signal is the valuable part of a blocking queue. `pipe-bell` and `jdk` both reached 1.5-2 ms wake after
  a 10 s gap and about 3% of the idle CPU; what failed them was cost and platform, not the idea.
- `xlibb/pubsub` was rejected on design grounds (fan-in against fan-out, a strand per subscriber per publish, shutdown
  that holds a lock while sleeping) and was not measured.

### Follow-up

No follow-up change is proposed. Had a strategy been adopted, the specs `mvu-runtime` (the loop, the idle backoff and
`sleepAfterStep` requirements) and `terminal-backend` (the input-polling requirements, which a shared blocking
consumer would have conflicted with) would have been the affected ones; `docs-site` would have changed only for the
options that became inert. Possible small items for the maintainer, none required: an upstream issue for the `pipe`
findings above; and, only if the idle cost matters, a separate change on the input path, which is where most of a
program's idle CPU is spent.
