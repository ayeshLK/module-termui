# Design

## Context

Three places wait by polling (see proposal.md for why this matters):

- `Engine.step` plus `sleep` in `run`, over `MessageQueue.takeAll`, with `backOff` lengthening the sleep.
- `UnixTerminal.nextEvent`, over `ByteQueue.takeAll`, with its own copy of `backOff`.
- `PromptBoard.ask`, two loops of `sleep(0.005)`.

The loop needs three things from a queue: any strand can push, the loop can block until something arrives, and the
loop can then take everything that is waiting without blocking (frame coalescing: apply all, draw once). The `Queue`
interface already isolates the mechanism. `xlibb/pipe` 1.6.1 provides a bounded blocking FIFO, but only one-at-a-time
`consume(timeout)`; an empty check is a `consume(0)` that completes through a `java.util.Timer` thread and returns a
`pipe:Error`. A source read found `Observable.callbackList` (a plain `ArrayList`) mutated on the timer thread without
the lock the producer and consumer paths use, and timer tasks for successful timed consumes left queued until their
timeout elapses. Both are unconfirmed suspicions until measured.

The terminal input path is out of scope: `nextEvent` and `queryCursor` deliberately co-read one byte queue, which two
blocking consumers cannot do.

## Goals / Non-Goals

**Goals:**

- Produce comparable numbers for four strategies on the workloads the runtime actually has.
- Confirm or refute the suspected race and the timer-task retention with a test that can fail.
- Decide, against fixed criteria written before the runs, whether any strategy is worth adopting.

**Non-Goals:**

- Changing anything under `ballerina/`, the options, or the specs.
- Measuring the terminal input path or pubsub (pubsub is rejected on design grounds, see the exploration).
- Tuning pipe or patching it upstream. A needed upstream change is a finding, not work in this change.

## Decisions

**Strategies compared.** One harness runs the same workloads against each, behind one small interface
(`push`, `waitForWork(timeout)`, `takeAll`, `close`):

| id | Strategy | Notes |
|---|---|---|
| `poll` | Current lock-guarded list, caller sleeps with the 1.0.1 backoff | Baseline. Reuses the same backoff schedule so the comparison is fair. |
| `pipe-queue` | `pipe:Pipe` is the queue: `consume(-1)` for the first message, `consume(0)` in a loop to drain | The straightforward adoption. Exercises the suspected race. |
| `pipe-bell` | Lock-guarded list stays the queue; a `pipe:Pipe` of limit 1 is a wake-up signal (`consume(-1)` to sleep, produce to wake) | Keeps the proven non-blocking `takeAll`; tests whether the drain path can be avoided. |
| `jdk` | `java.util.concurrent.LinkedBlockingQueue` through `jballerina.java` interop (`take`/`poll`/`drainTo`) | The control: a true blocking wait and a true non-blocking drain, with no third-party jar. |

Rationale: `pipe-queue` is what a reader would try first, `pipe-bell` is the cheapest way around the drain problem,
and `jdk` shows what is achievable if pipe is rejected. Alternatives not measured: worker channels and futures, which
cannot be completed from another strand of an isolated class, so they cannot be the queue.

**Messages.** Workloads use real shapes: a small `KeyEvent` record, a `ResizeEvent`, and a 4 KB paste string, all
`readonly`, built from the package's own types by copying their definitions into the harness (the harness does not
depend on the package).

**Workloads.**

1. Wake latency: a producer pushes one message after an idle gap of 0.1, 1, 3 and 10 s; latency is the monotonic time
   from push to the consumer holding the message. 30 samples per gap and strategy.
2. Idle CPU: a consumer waits 60 s with no producer; CPU time of the process is read from the OS at the start and end.
3. Throughput and drain cost: 1, 4 and 8 producers push 200,000 messages in total; the consumer drains in batches
   as they arrive. Report messages per second, and the time per drain call separately for batch sizes of 0 (empty),
   1, 50 and 1000.
4. Correctness stress: 8 producers on `thread: "any"` strands push numbered messages while the consumer drains with a
   timeout of 0, for at least 10 minutes and at least 100 runs of the short variant. Every message must arrive exactly
   once and in per-producer order. Count exceptions, hangs (a 30 s watchdog) and anything lost, duplicated or
   reordered.
5. Timer retention: 100,000 successful `consume(0.5)` calls, with heap and live timer-task count sampled afterward.
6. Shutdown: close the queue while a consumer is blocked and while 8 producers are blocked on a full queue; every
   waiter must return within 100 ms and none may hang or throw.
7. Build effect: build and pack the harness with each strategy; record the platform of the resulting package, the
   extra artifacts it pulls, and whether it runs on the local JDK 25 and Ballerina 2201.14.2.

**Go or no-go criteria (proposed; fix them before the first run and do not move them afterward).** A strategy is
recommended for adoption only if all of these hold against the `poll` baseline:

- Correctness: zero lost, duplicated or reordered messages and zero exceptions or hangs across all of workload 4 and 6.
- Latency: p95 wake latency after the 10 s gap is at most 5 ms (the baseline's is expected near 500 ms).
- Idle CPU: at most a third of the baseline's CPU over the 60 s.
- Cost: throughput is at least 50% of the baseline's at one producer, and a drain of an empty queue costs at most
  1 ms at the median.
- Build: the strategy does not require the package to be built for a different platform than it is today, or the
  difference is accepted explicitly in the follow-up change.

If `pipe-queue` fails correctness but `pipe-bell` or `jdk` passes everything, recommend that one. If none passes,
recommend keeping the polling backoff. A strategy that passes correctness and latency but fails only the build
criterion is reported as "viable with a platform cost", for the maintainer to decide.

## Risks / Trade-offs

- [The race is real but rare, so a short stress run misses it] → Run the stress for at least 10 minutes, repeat the
  short variant 100 times, and also run it under machine load (the existing `bench/stress_tests.sh` approach); report
  the run count, not just "no failures".
- [Laptop timing is noisy] → Report distributions (p50, p95, max) and the number of samples, not single numbers, and
  read them as magnitudes, as `bench/README.md` already advises.
- [The `jdk` variant's interop does not pass Ballerina values to Java cleanly] → Time-box it. If values cannot be
  stored and returned without copying or a conversion cost that dominates, report that as the finding.
- [A harness bug biases the comparison] → The four strategies share one workload driver and one interface, and the
  baseline is checked against `bench/idle_cpu.py` and `bench/latency.py` output on the built example before the other
  numbers are trusted.
- [Pipe's published artifact is unavailable or incompatible with the local toolchain] → That is itself a finding
  about the dependency; record it and stop evaluating pipe-based strategies.
