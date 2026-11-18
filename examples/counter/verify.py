#!/usr/bin/env python3
"""Runs the counter under a pseudo-terminal, types into it, and checks what it drew.

Usage: JAVA=/path/to/java25/bin/java python3 verify.py   (after `bal build` in this directory)
"""
import os, pty, select, sys, time

JAVA = os.environ.get("JAVA", "java")
JAR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "target", "bin", "counter.jar")

pid, fd = pty.fork()
if pid == 0:
    os.execvp(JAVA, [JAVA, "-jar", JAR])
output = b""


def read_until(text, timeout=60):
    global output
    end = time.time() + timeout
    while time.time() < end and text.encode() not in output:
        ready, _, _ = select.select([fd], [], [], 0.1)
        if ready:
            try:
                output += os.read(fd, 65536)
            except OSError:
                break
    return text.encode() in output


ok = read_until("count: 0")
first_frame = len(output)
for key in b"++-":
    os.write(fd, bytes([key]))
    time.sleep(0.2)
# After the first frame only the cell that changed is written (the digit), so the text "count: 1" is
# never written in one piece; seeing new output is the sign that the keys were handled and redrawn.
deadline = time.time() + 10
while time.time() < deadline and len(output) == first_frame:
    read_until("\x00", timeout=0.3)
ok = ok and len(output) > first_frame
os.write(fd, b"q")
# Keep reading while waiting: restoring the terminal waits for the program's output to be drained.
code = None
deadline = time.time() + 30
while time.time() < deadline and code is None:
    read_until("\x00", timeout=0.1)
    done, status = os.waitpid(pid, os.WNOHANG)
    if done:
        code = os.waitstatus_to_exitcode(status)
ok = ok and code == 0
print("PASS counter" if ok else "FAIL counter\n" + output.decode(errors="replace")[-400:])
sys.exit(0 if ok else 1)
