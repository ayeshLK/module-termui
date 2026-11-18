#!/usr/bin/env python3
"""Owns a pseudo-terminal for the tty tests.

Usage: pty_helper.py <work-dir> <plan.json>

The test process opens the slave device named in <work-dir>/tty and drives the plan through marker
files, so no step depends on timing alone. The plan is a list of steps:

  {"op": "wait", "file": "name"}                 wait until <work-dir>/name exists
  {"op": "touch", "file": "name"}                create <work-dir>/name
  {"op": "snapshot", "label": "x"}               record the terminal settings, then touch done-x
  {"op": "send", "hex": "1b5b41"}                write bytes to the master (as if typed)
  {"op": "drain", "label": "x", "seconds": 0.3}  read what the application wrote, store it as hex
  {"op": "drain", "label": "x", "until_file": "name"}  keep reading until <work-dir>/name exists, then a little longer
  {"op": "sleep", "seconds": 0.1}
  {"op": "resize", "rows": 30, "cols": 100}

Results are written to <work-dir>/result.json.
"""
import fcntl, json, os, pty, select, struct, sys, termios, time

work = sys.argv[1]
with open(sys.argv[2]) as f:
    plan = json.load(f)

master, slave = pty.openpty()
fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 24, 80, 0, 0))
path = os.ttyname(slave)
tmp = os.path.join(work, "tty.tmp")
with open(tmp, "w") as f:
    f.write(path)
os.rename(tmp, os.path.join(work, "tty"))

results = {"snapshots": {}, "drains": {}}

def touch(name):
    with open(os.path.join(work, name), "w") as f:
        f.write("x")

def wait_for(name, timeout=30):
    deadline = time.time() + timeout
    while time.time() < deadline:
        if os.path.exists(os.path.join(work, name)):
            return True
        time.sleep(0.01)
    results.setdefault("errors", []).append("timeout waiting for " + name)
    return False

def snapshot():
    iflag, oflag, cflag, lflag = termios.tcgetattr(master)[:4]
    # PENDIN is a transient kernel flag ("retype pending input"), not a setting, and it is set as a side
    # effect of changing modes, so it must not count as a difference.
    lflag &= ~getattr(termios, "PENDIN", 0)
    return {
        "icanon": bool(lflag & termios.ICANON),
        "echo": bool(lflag & termios.ECHO),
        "isig": bool(lflag & termios.ISIG),
        "opost": bool(oflag & termios.OPOST),
        "all": [iflag, oflag, cflag, lflag],
    }

for step in plan:
    op = step["op"]
    if op == "wait":
        if not wait_for(step["file"]):
            break
    elif op == "touch":
        touch(step["file"])
    elif op == "snapshot":
        results["snapshots"][step["label"]] = snapshot()
        touch("done-" + step["label"])
    elif op == "send":
        os.write(master, bytes.fromhex(step["hex"]))
    elif op == "drain":
        until = step.get("until_file")
        limit = time.time() + (60 if until else step.get("seconds", 0.3))
        grace = None
        data = b""
        while time.time() < limit:
            if until and grace is None and os.path.exists(os.path.join(work, until)):
                grace = time.time() + 0.3
            if grace is not None and time.time() > grace:
                break
            ready, _, _ = select.select([master], [], [], 0.05)
            if ready:
                try:
                    data += os.read(master, 65536)
                except OSError:
                    break
        results["drains"][step["label"]] = data.hex()
    elif op == "sleep":
        time.sleep(step["seconds"])
    elif op == "resize":
        fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", step["rows"], step["cols"], 0, 0))

with open(os.path.join(work, "result.json.tmp"), "w") as f:
    json.dump(results, f)
os.rename(os.path.join(work, "result.json.tmp"), os.path.join(work, "result.json"))
