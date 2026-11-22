#!/usr/bin/env python3
"""CPU time of a waiting queue strategy, as a percentage of one core.

Runs the harness's `idle` workload, waits for its IDLE_READY marker, lets it settle for --warmup seconds (long enough
for the polling baseline's backoff to reach its ceiling, about 13 s), then measures the CPU time the process uses over
--window seconds in which nothing is pushed. Same method as bench/idle_cpu.py (CPU time read with ps), without a
pseudo-terminal.

Usage:  python3 idle_cpu.py STRATEGY [--warmup 16] [--window 60] [--runs 1]
"""
import argparse, os, subprocess, sys, time

HERE = os.path.dirname(os.path.abspath(__file__))
JAR = os.path.join(HERE, "target", "bin", "blocking_queue_eval.jar")


def cpu_seconds(pid):
    out = subprocess.run(["ps", "-o", "time=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    if not out:
        return None
    parts = out.split(":")
    seconds = float(parts[-1]) + 60 * int(parts[-2])
    if len(parts) > 2:
        seconds += 3600 * int(parts[-3])
    return seconds


def one_run(strategy, warmup, window):
    java = os.environ.get("JAVA", "java")
    process = subprocess.Popen([java, "-jar", JAR, "idle", strategy, str(warmup + window + 30)],
                               stdout=subprocess.PIPE, text=True)
    started = time.time()
    for line in process.stdout:
        if line.strip() == "IDLE_READY":
            break
        if time.time() - started > 60:
            process.kill()
            raise SystemExit("no IDLE_READY within 60 s")
    time.sleep(warmup)
    before = cpu_seconds(process.pid)
    time.sleep(window)
    after = cpu_seconds(process.pid)
    process.kill()
    if before is None or after is None:
        raise SystemExit("the process exited while it was measured")
    return after - before


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("strategy")
    parser.add_argument("--warmup", type=float, default=16)
    parser.add_argument("--window", type=float, default=60)
    parser.add_argument("--runs", type=int, default=1)
    options = parser.parse_args()
    for run in range(options.runs):
        used = one_run(options.strategy, options.warmup, options.window)
        print("RESULT workload=idleCpu strategy=%s run=%d warmup=%g window=%g cpuSeconds=%.2f percentOfOneCore=%.2f"
              % (options.strategy, run, options.warmup, options.window, used, used / options.window * 100))
        sys.stdout.flush()


if __name__ == "__main__":
    sys.exit(main())
