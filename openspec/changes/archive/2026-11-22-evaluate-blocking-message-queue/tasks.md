# Tasks

## 1. Harness and baseline

- [x] 1.1 Create the harness project `bench/blocking-queue-eval/` (its own `Ballerina.toml`, not part of the `ballerina/` package build) with the shared interface (`push`, `waitForWork(timeout)`, `takeAll`, `close`), the message shapes from the design, and the `poll` strategy using the 1.0.1 backoff schedule. Verify `bal build` succeeds in that directory and a smoke test pushes and takes a message through `poll`.
- [x] 1.2 Add the shared workload driver (latency, idle, throughput, stress, retention, shutdown) so every strategy runs the identical code, and a `RESULTS` printer that emits one machine-readable line per measurement. Verify by running the driver against `poll` and seeing every workload print a result.
- [x] 1.3 Cross-check the baseline: build `examples/counter`, run `bench/idle_cpu.py` and `bench/latency.py` on it, and compare with the harness's `poll` idle CPU and 10 s wake latency. Verify the two agree to within the noise (same order of magnitude), and note any difference in `findings.md`; do not proceed to the other strategies until the baseline is trusted.
- [x] 1.4 Add `bench/blocking-queue-eval/README.md` describing how to run each workload and what it measures. Verify by following it from a clean checkout.

## 2. Pipe strategies

- [x] 2.1 Add `xlibb/pipe` 1.6.1 as the harness's dependency and implement `pipe-queue` (`consume(-1)` then a `consume(0)` drain loop that treats the timeout error as empty and any other error as closed). Verify the project builds, resolves the package from Ballerina Central on the local toolchain, and passes the smoke test; if it cannot be resolved or run on JDK 25 / 2201.14.2, record that in `findings.md` as a finding and skip tasks 2.2 and 3.x for pipe.
- [x] 2.2 Implement `pipe-bell` (list stays the queue, a limit-1 pipe is the wake-up signal, producers signal without blocking). Verify it passes the same smoke test and that a push issued while the consumer is already awake does not block the producer.
- [x] 2.3 Run workloads 1 and 2 (wake latency, idle CPU) for `poll`, `pipe-queue` and `pipe-bell`. Verify results are recorded in `findings.md` with sample counts, p50, p95 and max per gap.

## 3. JDK control

- [x] 3.1 Implement `jdk` over `java.util.concurrent.LinkedBlockingQueue` through `jballerina.java` interop, time-boxed to one session. Verify it passes the smoke test with the three message shapes; if values cannot cross the interop without a dominating conversion cost, record that in `findings.md` and stop this strategy there.
- [x] 3.2 Run workloads 1 and 2 for `jdk` and add its rows to the `findings.md` tables. Verify the table has the same columns as the other strategies.

## 4. Throughput, retention and shutdown

- [x] 4.1 Run workload 3 (throughput and per-drain cost at batch sizes 0, 1, 50, 1000, with 1, 4 and 8 producers) for every strategy that built. Verify the numbers are in `findings.md` and the empty-drain median per strategy is stated.
- [x] 4.2 Run workload 5 (100,000 successful timed consumes, then heap and live timer-task count) for the pipe strategies. Verify `findings.md` states whether tasks are retained and how much memory they hold.
- [x] 4.3 Run workload 6 (close while a consumer is blocked, and while 8 producers are blocked on a full queue) for every strategy that has a bound or can block. Verify each waiter's return time is recorded and any hang or exception is called out.

## 5. Correctness stress

- [x] 5.1 Implement the stress check (8 producers on `thread: "any"` strands, per-producer sequence numbers, timeout-0 drains, 30 s watchdog, exactly-once and per-producer-order verification). Verify it fails when a deliberately broken queue (one that drops every thousandth message) is substituted, so a pass means something.
- [x] 5.2 Run the short variant 100 times and the long variant for at least 10 minutes per strategy, once on an idle machine and once under load using the approach in `bench/stress_tests.sh`. Verify `findings.md` records the run counts, the load level, and every exception, hang, loss, duplicate or reorder with the strategy that produced it.

## 6. Build effect and decision

- [x] 6.1 Build and pack the harness with each strategy and record the resulting package's platform, extra artifacts pulled, and whether it runs on the local toolchain. Verify the answer to "does adopting this make the package platform-specific?" is stated per strategy in `findings.md`.
- [x] 6.2 Write the conclusion in `findings.md`: each strategy's result against every criterion in `design.md` (pass or fail, with the number), and the recommendation (adopt which strategy, adopt with a stated platform cost, or keep polling). Verify every criterion has a row for every strategy and that no criterion was changed since the design was written (compare with `design.md` in version control).
- [x] 6.3 If the recommendation is to adopt a strategy, list the follow-up change it implies (engine loop, `PromptBoard`, the options that become inert, the spec requirements to modify) as a short proposal outline at the end of `findings.md`. Verify it names the affected specs from `openspec list --specs`. If the recommendation is to keep polling, say so and record what was learned.

## Workflow follow-up

- Review `findings.md` with the maintainer before any follow-up change is created.
- Archive this change once the findings are accepted; the harness directory stays in `bench/` as the reproducible record.
