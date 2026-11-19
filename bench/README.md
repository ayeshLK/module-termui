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
