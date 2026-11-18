#!/usr/bin/env python3
"""Records the agent harness: a prompt typed by a person, a streamed answer, and two approvals.

Usage: JAVA=/path/to/java25/bin/java python3 record_demo.py [output-directory]   (after `bal build`)
Needs `agg` (https://github.com/asciinema/agg) to render the GIF; the .cast is written either way.
"""
import fcntl, json, os, pty, select, shutil, struct, subprocess, sys, termios, time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "docs", "assets"))
JAVA = os.environ.get("JAVA", "java")
JAR = os.path.join(HERE, "target", "bin", "agent_harness.jar")
COLS, ROWS = 92, 26

events = []
started = time.time()
seen = b""


def now():
    return time.time() - started


def main():
    global seen
    env = dict(os.environ, TERM="xterm-256color", COLUMNS=str(COLS), LINES=str(ROWS))
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe(JAVA, [JAVA, "-jar", JAR], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))

    def pump(seconds=0.05):
        global seen
        ready, _, _ = select.select([fd], [], [], seconds)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if data:
                seen += data
                events.append([round(now(), 4), "o", data.decode("utf-8", errors="replace")])
        return True

    def wait_for(text, timeout=60):
        mark = len(seen)
        end = time.time() + timeout
        while time.time() < end and text.encode() not in seen[mark:]:
            pump()
        return text.encode() in seen[mark:]

    def idle(seconds):
        end = time.time() + seconds
        while time.time() < end:
            pump()

    def type_text(text):
        for ch in text:
            os.write(fd, ch.encode())
            idle(0.07)

    wait_for("❯ ")
    idle(1.2)
    type_text("fix the bug in the handler")
    idle(0.5)
    os.write(fd, b"\r")
    wait_for("Allow Edit(src/handler.bal)?")
    idle(1.6)                       # a person reads the question
    os.write(fd, b"y")
    wait_for("Allow Bash(bal test)?")
    idle(1.4)
    os.write(fd, b"y")
    wait_for("All 12 tests pass")
    idle(2.4)
    os.write(fd, b"\x04")           # Ctrl+D
    deadline = time.time() + 20
    while time.time() < deadline:
        pump()
        try:
            done, _ = os.waitpid(pid, os.WNOHANG)
        except ChildProcessError:
            break
        if done:
            break
    idle(0.8)

    os.makedirs(OUT, exist_ok=True)
    cast = os.path.join(OUT, "harness-demo.cast")
    with open(cast, "w") as f:
        f.write(json.dumps({"version": 2, "width": COLS, "height": ROWS, "timestamp": 0,
                            "env": {"TERM": "xterm-256color", "SHELL": "/bin/sh"}}) + "\n")
        for event in events:
            f.write(json.dumps(event) + "\n")
    print(f"wrote {cast} ({events[-1][0]:.1f} s)")
    if shutil.which("agg"):
        gif = os.path.join(OUT, "harness-demo.gif")
        subprocess.run(["agg", "--quiet", "--font-size", "15", "--theme", "monokai", "--idle-time-limit", "1.8",
                        "--fps-cap", "20", cast, gif], check=True)
        print(f"wrote {gif} ({os.path.getsize(gif) // 1024} KB)")
    else:
        print("agg not found: install it to render the GIF")


main()
