#!/usr/bin/env python3
"""How much CPU and memory a termui program uses while it is waiting for input.

Runs a built executable jar on a pseudo-terminal, lets it settle, then measures the CPU time it uses over a
window in which nobody touches it. A program that is idle should use close to nothing and write nothing.

Usage:  JAVA=/path/to/java25/bin/java python3 bench/idle_cpu.py examples/counter/target/bin/counter.jar
        python3 bench/idle_cpu.py JAR [--warmup 4] [--window 20] [--max-cpu 3] [-- program arguments]

Needs only the Python standard library. Timing on a shared machine is noisy: run it a few times and treat the
numbers as magnitudes, not as exact figures. Exits with status 1 when --max-cpu is given and exceeded.
"""
import argparse, fcntl, os, pty, select, signal, struct, subprocess, sys, termios, time


def cpu_seconds(pid):
    out = subprocess.run(["ps", "-o", "time=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    if not out:
        return None
    parts = out.split(":")
    seconds = float(parts[-1]) + 60 * int(parts[-2])
    if len(parts) > 2:
        seconds += 3600 * int(parts[-3])
    return seconds


def rss_mb(pid):
    out = subprocess.run(["ps", "-o", "rss=", "-p", str(pid)], capture_output=True, text=True).stdout.strip()
    return int(out) / 1024 if out else 0


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("jar")
    parser.add_argument("--warmup", type=float, default=4, help="seconds to settle before measuring (default 4)")
    parser.add_argument("--window", type=float, default=20, help="seconds to measure (default 20)")
    parser.add_argument("--rows", type=int, default=40)
    parser.add_argument("--cols", type=int, default=100)
    parser.add_argument("--max-cpu", type=float, help="fail when the idle CPU, as a percentage of one core, is above this")
    parser.add_argument("args", nargs="*", help="arguments for the program (after --)")
    options = parser.parse_args()

    java = os.environ.get("JAVA", "java")
    pid, master = pty.fork()
    if pid == 0:
        os.execv(java, [java, "-jar", options.jar] + options.args)
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", options.rows, options.cols, 0, 0))

    def drain(seconds):
        end = time.time() + seconds
        total = 0
        while time.time() < end:
            ready, _, _ = select.select([master], [], [], 0.05)
            if ready:
                try:
                    total += len(os.read(master, 65536))
                except OSError:
                    break
        return total

    started = time.time()
    while True:
        ready, _, _ = select.select([master], [], [], 0.01)
        if ready:
            os.read(master, 65536)
            break
        if time.time() - started > 30:
            print("the program wrote nothing within 30 s", file=sys.stderr)
            os.kill(pid, signal.SIGKILL)
            return 2
    first = (time.time() - started) * 1000
    drain(options.warmup)
    before = cpu_seconds(pid)
    written = drain(options.window)
    after = cpu_seconds(pid)
    memory = rss_mb(pid)
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    if before is None or after is None:
        print("the program exited while it was being measured", file=sys.stderr)
        return 2
    percent = (after - before) / options.window * 100
    print("first output after %.0f ms" % first)
    print("idle %.0f s: cpu %.2f s (%.1f%% of one core), bytes written while idle: %d, RSS %.0f MB"
          % (options.window, after - before, percent, written, memory))
    if options.max_cpu is not None and percent > options.max_cpu:
        print("FAIL: above the limit of %.1f%%" % options.max_cpu)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
