#!/usr/bin/env python3
"""How long a key press takes to produce output, after pauses of different lengths.

Runs a built executable jar on a pseudo-terminal, presses a key that makes the program redraw (the counter
example's `+`), and measures the time to the first byte of output. The program backs its loops off while it is
idle (see Options.maxPollInterval), so the first key after a long pause waits longer than one after a short pause:
this script shows by how much.

Usage:  JAVA=/path/to/java25/bin/java python3 bench/latency.py examples/counter/target/bin/counter.jar
        python3 bench/latency.py JAR [--gaps 0.05,1,3,15] [--samples 8] [--key +] [-- program arguments]

Needs only the Python standard library. The gaps are the idle time before each key press; the longest gap sets how
long the run takes (about samples x the sum of the gaps).
"""
import argparse, fcntl, os, pty, select, signal, statistics, struct, sys, termios, time


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("jar")
    parser.add_argument("--gaps", default="0.05,1,3,15", help="idle seconds before each key press, comma separated")
    parser.add_argument("--samples", type=int, default=8, help="key presses per gap")
    parser.add_argument("--key", default="+", help="the key to press (default +)")
    parser.add_argument("--rows", type=int, default=40)
    parser.add_argument("--cols", type=int, default=100)
    parser.add_argument("args", nargs="*", help="arguments for the program (after --)")
    options = parser.parse_args()

    java = os.environ.get("JAVA", "java")
    pid, master = pty.fork()
    if pid == 0:
        os.execv(java, [java, "-jar", options.jar] + options.args)
    fcntl.ioctl(master, termios.TIOCSWINSZ, struct.pack("HHHH", options.rows, options.cols, 0, 0))

    def first_byte(timeout=5.0):
        end = time.time() + timeout
        while time.time() < end:
            ready, _, _ = select.select([master], [], [], 0.0005)
            if ready:
                os.read(master, 65536)
                return True
        return False

    def settle():
        while True:
            ready, _, _ = select.select([master], [], [], 0.05)
            if not ready:
                return
            os.read(master, 65536)

    if not first_byte(30):
        print("the program wrote nothing within 30 s", file=sys.stderr)
        os.kill(pid, signal.SIGKILL)
        return 2
    settle()
    time.sleep(3)  # let the JIT settle
    settle()

    print("key -> first output byte (ms)   gap before the key   n    p50    p90    max")
    for gap in [float(g) for g in options.gaps.split(",")]:
        samples = []
        for _ in range(options.samples):
            time.sleep(gap)
            started = time.perf_counter()
            os.write(master, options.key.encode())
            if not first_byte():
                print("timeout after a gap of %s s" % gap, file=sys.stderr)
                break
            samples.append((time.perf_counter() - started) * 1000)
            settle()
        if samples:
            ordered = sorted(samples)
            p90 = ordered[min(len(ordered) - 1, int(len(ordered) * 0.9))]
            print("%-31s %-20s %-4d %-6.1f %-6.1f %-6.1f" % ("", "%g s" % gap, len(samples), statistics.median(samples), p90, max(samples)))
    try:
        os.kill(pid, signal.SIGKILL)
    except ProcessLookupError:
        pass
    return 0


if __name__ == "__main__":
    sys.exit(main())
