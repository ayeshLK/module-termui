#!/usr/bin/env python3
"""End-to-end check of the agent demo: interactive, piped output, headless, and signals.

Usage: JAVA=/path/to/java25/bin/java python3 verify.py   (after `bal build` in this directory)
"""
import os, pty, select, signal, subprocess, sys, tempfile, termios, time

JAVA = os.environ.get("JAVA", "java")
JAR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "target", "bin", "agent_demo.jar")
failures = []


def check(name, ok, detail=""):
    print(("PASS " if ok else "FAIL ") + name + ("" if ok else "  -> " + detail))
    if not ok:
        failures.append(name)


def group_pids(pgid):
    out = subprocess.run(["ps", "-axo", "pid=,pgid=,command="], capture_output=True, text=True).stdout
    return [(int(p[0]), p[2]) for p in (l.split(None, 2) for l in out.splitlines()) if len(p) == 3 and int(p[1]) == pgid]


class Session:
    """The app running with a pseudo-terminal as its terminal."""

    def __init__(self, shell_command):
        self.pid, self.fd = pty.fork()
        if self.pid == 0:
            os.execvp("sh", ["sh", "-c", shell_command])
        self.output = b""

    def pump(self, seconds=0.1):
        ready, _, _ = select.select([self.fd], [], [], seconds)
        if ready:
            try:
                data = os.read(self.fd, 65536)
                if data:
                    self.output += data
                    return True
            except OSError:
                return False
        return True

    def wait_for(self, text, timeout=60):
        end = time.time() + timeout
        while time.time() < end:
            if text.encode() in self.output:
                return True
            if not self.pump():
                break
        return text.encode() in self.output

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


def app(redirect=""):
    return f"'{JAVA}' -jar '{JAR}' {redirect}"


# 1. interactive: ask, answer yes, finish
s = Session(app())
check("interactive: the question is shown", s.wait_for("Run `make test`?"), s.output.decode(errors="replace")[-300:])
check("interactive: the terminal is raw while it runs", s.mode() == "raw", s.mode())
s.send(b"y")
code = s.finish()
text = s.output.decode(errors="replace")
check("interactive: exits normally", code == 0, str(code))
check("interactive: committed text and result appear", "approved=true" in text and "Running the tests now." in text, text[-300:])
check("interactive: the terminal is restored at exit", s.mode() == "cooked", s.mode())
s.kill_all()

# 2. output piped to a file: only the result goes there, the interface stays on the terminal
with tempfile.TemporaryDirectory() as d:
    result = os.path.join(d, "stdout.txt")
    s = Session(app(f"> '{result}'"))
    s.wait_for("Run `make test`?")
    s.send(b"y")
    code = s.finish()
    content = open(result, "rb").read()
    check("piped output: the file holds only the result", content == b"approved=true\n", repr(content))
    check("piped output: the interface was drawn on the terminal", b"\x1b[" in s.output and b"Running the tests now." in s.output)
    s.kill_all()

# 3. headless: plain, no questions asked, identical bytes each time
outputs = []
with tempfile.TemporaryDirectory() as d:
    for run in range(2):
        path = os.path.join(d, f"out{run}.txt")
        subprocess.run(["sh", "-c", app(f"< /dev/null > '{path}' 2>/dev/null")], check=False, timeout=90)
        outputs.append(open(path, "rb").read())
check("headless: no escape sequences or carriage returns", b"\x1b" not in outputs[0] and b"\r" not in outputs[0], repr(outputs[0][:200]))
check("headless: the question was not asked and the default (deny) was used", b"approved=false" in outputs[0] and b"Understood" in outputs[0], repr(outputs[0]))
check("headless: two runs produce identical bytes", outputs[0] == outputs[1])

# 4. signals leave the terminal restored
for name, sig in (("SIGTERM", signal.SIGTERM), ("SIGINT", signal.SIGINT), ("SIGHUP", signal.SIGHUP)):
    s = Session(app())
    shown = s.wait_for("Run `make test`?")
    jvm = [pid for pid, cmd in group_pids(s.pid) if "java" in cmd.split()[0] and "agent_demo" in cmd]
    raw = s.mode()
    if jvm:
        os.kill(jvm[-1], sig)
    code = s.finish(15)
    check(f"{name}: the question was up and the terminal raw", shown and raw == "raw" and bool(jvm), f"{shown} {raw} {jvm}")
    check(f"{name}: the process exits", code is not None, "still running")
    check(f"{name}: the terminal is restored", s.mode() == "cooked", s.mode())
    s.kill_all()

print()
print("FAILED: " + ", ".join(failures) if failures else "all checks passed")
sys.exit(1 if failures else 0)
