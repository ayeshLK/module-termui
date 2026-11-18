#!/usr/bin/env python3
"""End-to-end check of the agent harness under a pseudo-terminal.

Usage: JAVA=/path/to/java25/bin/java python3 verify.py   (after `bal build` in this directory)

Needs `pyte` (pip install pyte): the output is fed to a terminal emulator that also answers the cursor
position request the app sends, so the checks can look at what is on the screen.
"""
import fcntl, os, pty, select, signal, struct, subprocess, sys, termios, time
import pyte

JAVA = os.environ.get("JAVA", "java")
JAR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "target", "bin", "agent_harness.jar")
# tall enough for the whole first turn to fit above the input, so the banner is still on screen after it
ROWS, COLS = 50, 100
failures = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  -> " + detail))
    if not ok:
        failures.append(name)


def group_pids(pgid):
    out = subprocess.run(["ps", "-axo", "pid=,pgid=,command="], capture_output=True, text=True).stdout
    return [(int(p[0]), p[2]) for p in (l.split(None, 2) for l in out.splitlines()) if len(p) == 3 and int(p[1]) == pgid]


class Emulator(pyte.Screen):
    """A screen that answers the cursor position request (ESC [ 6 n) the way a terminal does."""

    def __init__(self, columns, lines):
        super().__init__(columns, lines)
        self.fd = None
        self.requests = 0

    def report_device_status(self, mode):
        if mode == 6 and self.fd is not None:
            self.requests += 1
            os.write(self.fd, f"\x1b[{self.cursor.y + 1};{self.cursor.x + 1}R".encode())
        else:
            super().report_device_status(mode)


class App:
    def __init__(self):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
            os.execvp(JAVA, [JAVA, "-jar", JAR])
        self.output = b""
        self.screen = Emulator(COLS, ROWS)
        self.screen.fd = self.fd
        self.stream = pyte.ByteStream(self.screen)

    def rows(self):
        return [row.rstrip() for row in self.screen.display]

    def on_screen(self, text):
        return any(text in row for row in self.rows())

    def pump(self, seconds=0.1):
        ready, _, _ = select.select([self.fd], [], [], seconds)
        if ready:
            try:
                data = os.read(self.fd, 65536)
                if data:
                    self.output += data
                    self.stream.feed(data)
            except OSError:
                return False
        return True

    def wait_for(self, text, timeout=60, since=0):
        end = time.time() + timeout
        while time.time() < end:
            if text.encode() in self.output[since:]:
                return True
            if not self.pump():
                break
        return text.encode() in self.output[since:]

    def type(self, text):
        for ch in text:
            os.write(self.fd, ch.encode())
            self.pump(0.02)

    def send(self, data):
        os.write(self.fd, data)

    def mode(self):
        lflag = termios.tcgetattr(self.fd)[3]
        return "cooked" if (lflag & termios.ICANON and lflag & termios.ECHO) else "raw"

    def finish(self, timeout=30):
        end = time.time() + timeout
        while time.time() < end:
            self.pump(0.05)
            try:
                pid, status = os.waitpid(self.pid, os.WNOHANG)
            except ChildProcessError:
                return 0
            if pid:
                for _ in range(10):
                    self.pump(0.05)
                return os.waitstatus_to_exitcode(status)
        return None

    def kill_all(self):
        for pid, _ in group_pids(self.pid):
            try:
                os.kill(pid, signal.SIGKILL)
            except ProcessLookupError:
                pass

    def text(self):
        return self.output.decode(errors="replace")


# 1. a turn with tool calls: two approvals, the answer streams, then Ctrl+D quits
app = App()
check("shows the banner and the prompt", app.wait_for("Welcome to Dummy Agent") and app.wait_for("❯ "), app.text()[-300:])
check("the terminal is raw while it runs", app.mode() == "raw", app.mode())
app.pump(0.3)
check("the app asked where the cursor is", app.screen.requests >= 1, "no cursor position request")
check("the input is on the bottom rows from the first frame",
      app.rows()[ROWS - 2].startswith("❯") and "ctrl+d to quit" in app.rows()[ROWS - 1], repr(app.rows()[-4:]))
check("the banner is at the top, untouched", app.rows()[0].startswith("╭") and app.on_screen("Welcome to Dummy Agent"), repr(app.rows()[:4]))
app.type("fix the bug in the handler")
app.send(b"\r")
check("asks before editing a file", app.wait_for("Allow Edit(src/handler.bal)?"), app.text()[-300:])
app.send(b"y")
check("asks before running a command", app.wait_for("Allow Bash(bal test)?"), app.text()[-300:])
app.send(b"y")
check("streams the final answer", app.wait_for("All 12 tests pass"), app.text()[-300:])
check("records the tool results", "12 passed, 0 failed" in app.text() and "+3 -1 lines" in app.text())
app.pump(0.5)
check("the banner is still on screen after the first turn", app.rows()[0].startswith("╭") and app.on_screen("Welcome to Dummy Agent"), repr(app.rows()[:6]))
check("the input is still on the bottom rows after the turn",
      app.rows()[ROWS - 2].startswith("❯") and "ctrl+d to quit" in app.rows()[ROWS - 1], repr(app.rows()[-4:]))
app.send(b"\x04")
code = app.finish()
check("Ctrl+D quits normally", code == 0 and "Goodbye" in app.text(), f"{code}")
check("the terminal is restored", app.mode() == "cooked", app.mode())
app.kill_all()

# 2. denying an approval
app = App()
app.wait_for("❯ ")
app.type("fix the bug")
app.send(b"\r")
app.wait_for("Allow Edit(src/handler.bal)?")
app.send(b"n")
check("a denied tool call is reported", app.wait_for("denied by user"), app.text()[-300:])
# the plan asks about the next tool too; keys typed while a question is open belong to the question
app.wait_for("Allow Bash(bal test)?")
app.send(b"n")
app.wait_for("All 12 tests pass")
time.sleep(0.5)
app.type("/exit")
app.send(b"\r")
check("/exit quits normally", app.finish() == 0)
app.kill_all()

# 3. Esc interrupts a streaming answer
app = App()
app.wait_for("❯ ")
app.type("explain how streaming works")
app.send(b"\r")
check("the answer starts streaming", app.wait_for("Great question"), app.text()[-300:])
app.send(b"\x1b")
check("Esc interrupts it", app.wait_for("Interrupted by user"), app.text()[-300:])
app.type("/exit")
app.send(b"\r")
app.finish()
app.kill_all()

# 4. signals leave the terminal restored
for name, sig in (("SIGTERM", signal.SIGTERM), ("SIGINT", signal.SIGINT), ("SIGHUP", signal.SIGHUP)):
    app = App()
    app.wait_for("❯ ")
    jvm = [pid for pid, cmd in group_pids(app.pid) if cmd.split()[0].endswith("java") and "agent_harness" in cmd]
    raw = app.mode()
    if jvm:
        os.kill(jvm[-1], sig)
    code = app.finish(15)
    check(f"{name}: the process exits and the terminal is restored", code is not None and raw == "raw" and app.mode() == "cooked",
          f"exit={code} before={raw} after={app.mode()} jvm={bool(jvm)}")
    app.kill_all()

# 5. no terminal: plain text, and it does not wait for input
result = subprocess.run([JAVA, "-jar", JAR], stdin=subprocess.DEVNULL, capture_output=True, timeout=60)
out = result.stdout
check("headless: exits normally with plain text", result.returncode == 0 and b"Welcome to Dummy Agent" in out and b"\x1b" not in out and b"\r" not in out, repr(out[:200]))

print()
print("FAILED: " + ", ".join(failures) if failures else "all checks passed")
sys.exit(1 if failures else 0)
