#!/usr/bin/env python3
"""Records the counter as an asciinema cast: a few key presses, then q.

Usage: JAVA=/path/to/java25/bin/java python3 record_demo.py [output.cast]   (after `bal build` here)
The recording is of the real program on a pseudo-terminal, and is played on the documentation site.
"""
import fcntl, json, os, pty, select, struct, sys, termios, time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "site", "public", "casts", "counter-demo.cast"))
JAVA = os.environ.get("JAVA", "java")
JAR = os.path.join(HERE, "target", "bin", "counter.jar")
COLS, ROWS = 60, 8
# What to type and when (seconds after the first frame), as a person would
SCRIPT = [(1.0, "+"), (0.5, "+"), (0.4, "+"), (0.9, "-"), (0.7, "+"), (1.2, "q")]

pid, fd = pty.fork()
if pid == 0:
    os.environ["TERM"] = "xterm-256color"
    os.environ["COLUMNS"], os.environ["LINES"] = str(COLS), str(ROWS)
    os.execvp(JAVA, [JAVA, "-jar", JAR])
fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))

events = []
started = None


def drain(timeout):
    """Read what the program wrote for up to `timeout` seconds, recording it with timestamps."""
    global started
    end = time.time() + timeout
    while time.time() < end:
        ready, _, _ = select.select([fd], [], [], 0.02)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if not data:
                return False
            if started is None:
                started = time.time()
            events.append([round(time.time() - started, 4), "o", data.decode("utf-8", "replace")])
    return True


# wait for the first frame (JVM start-up)
deadline = time.time() + 60
while started is None and time.time() < deadline:
    drain(0.2)
if started is None:
    sys.exit("the program drew nothing")
for pause, key in SCRIPT:
    drain(pause)
    os.write(fd, key.encode())
drain(1.5)

os.makedirs(os.path.dirname(OUT), exist_ok=True)
with open(OUT, "w") as f:
    f.write(json.dumps({"version": 2, "width": COLS, "height": ROWS, "timestamp": 0,
                        "env": {"TERM": "xterm-256color", "SHELL": "/bin/sh"}}) + "\n")
    for e in events:
        f.write(json.dumps(e) + "\n")
print(f"wrote {OUT}: {len(events)} events, {events[-1][0]:.1f} s")
