# Measuring a termui program

Two small scripts that run a built executable jar on a pseudo-terminal and report numbers. They need only
Python 3 (no packages) and a JDK 25 (`JAVA=/path/to/java`), and work on macOS and Linux.

```sh
(cd examples/counter && bal build)
JAVA=$(which java) python3 bench/idle_cpu.py examples/counter/target/bin/counter.jar
JAVA=$(which java) python3 bench/latency.py examples/counter/target/bin/counter.jar
```

- **`idle_cpu.py`**: the CPU time, memory and bytes written by a program that is only waiting for a key. A
  waiting program should use a few percent of one core at most and write nothing. Use `--max-cpu 3` to make it
  fail above a limit.
- **`latency.py`**: the time from a key press to the first byte of output, after idle gaps of different lengths.
  The loops back off while idle (`Options.maxPollInterval`, 0.5 s by default), so the first key after a long
  pause waits longer than one after a short pause; this shows by how much.

Timing on a laptop or a shared CI runner is noisy, so these are for looking at before a release or after a change
to the loops, not for gating a build. Run each a few times and read the numbers as magnitudes.

## Stressing the tests

A test that passes on a quiet laptop can fail on a busy CI runner. `stress_tests.sh` runs `bal test` repeatedly while the machine is saturated with busy processes, and counts a run as a pass only if tests actually ran and none failed (a package that does not compile prints no `[fail]` line, so "nothing failed" is not enough):

```sh
JAVA_HOME=... LOAD=66 bench/stress_tests.sh ballerina 6                       # the whole package, six runs
JAVA_HOME=... LOAD=66 bench/stress_tests.sh ballerina 6 --groups tty          # the tests that need a pty
JAVA_HOME=... LOAD=66 bench/stress_tests.sh examples/best-practices 8
```

`LOAD` defaults to twice the number of cores; on an 11-core laptop 22 processes slow a run by about 20 to 35% and 66 find the tests that need a margin. Run it after adding or changing a test that sleeps, reads a clock, or asserts on a duration.

What a sweep found (2026-11-19, 66 busy processes on 11 cores, 290 package tests plus the examples' tests): one flaky test, `testWritingFramesIsFastEnough`, whose floor of 100 frames/s failed in 4 of 10 runs (it measures about 1000 frames/s on a quiet machine, 170 to 320 with 22 busy processes and 89 to 138 with 66). Its floor is now 30, which still fails a write path slowed to 17 frames/s. Every other timing assertion passed every run.

Rules for timing assertions:

- A **lower bound** ("waited at least 0.19 s") cannot get harder under load. An **upper bound** can, so give it a large margin over what it normally measures, at least five times, and never an absolute limit you have not seen exceeded under load.
- Prefer **waiting for a condition** to counting or sleeping: wait until the message arrived, then assert on what happened, not on how many things happened by a moment in time.
- When the timing is the point, make it **deterministic** instead of long: push the key while the program is in a pause much longer than the time the key takes, so the outcome does not depend on a race.
- Print the measurement a threshold is compared with, as `testWritingFramesIsFastEnough` does, so a margin can be judged from the logs without guessing.

The upper-bound assertions the sweep reviewed, and how far each is from what it measures, are the ones to look at first if a timing test ever fails: the cursor-request time in `unix_test.bal` (under 0.2 s), the remembered unsupported terminal (under 0.05 s), the idle loop with the backoff off (at most 0.05 s), and the longest tick gap in `examples/best-practices` (under 0.3 s).
