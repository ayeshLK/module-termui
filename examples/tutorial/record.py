#!/usr/bin/env python3
"""Records a tutorial step as an asciinema cast: a scripted person typing into the real program.

Usage: JAVA=/path/to/java25/bin/java python3 record.py <step-directory-name> [output-directory]
       (after `bal build` in that step's directory; needs `pyte`: pip install pyte)

pyte plays the terminal: it answers the program's cursor position request the way a real terminal
does, so a program that anchors to the bottom is drawn as a user would see it. This is an author-time
tool; CI does not run it. Add a script for a new step to SCRIPTS.
"""
import fcntl, json, os, pty, select, shutil, struct, sys, tempfile, termios, time
import pyte

HERE = os.path.dirname(os.path.abspath(__file__))
JAVA = os.environ.get("JAVA", "java")
COLS, ROWS = 90, 14
SIZES = {"step5-approval": (90, 18), "quick-start": (70, 10)}   # programs that need other than the default size
# Programs that do not live in a tutorial step directory, relative to this file. They also run in an empty
# folder, so a program that saves a file starts from nothing and leaves no file in the repository.
ELSEWHERE = {"quick-start": "../quick-start"}

# ("wait", text): wait for text to appear. ("idle", seconds): let time pass. ("type", text): type it like a
# person. ("key", bytes): send one key. The last step should end the program.
SCRIPTS = {
    "quick-start": [
        ("wait", "Nothing to do"), ("idle", 1.2),
        ("key", b"a"), ("idle", 0.4), ("type", "buy milk"), ("idle", 0.4), ("key", b"\r"), ("idle", 0.8),
        ("key", b"a"), ("idle", 0.4), ("type", "write the docs"), ("idle", 0.4), ("key", b"\r"), ("idle", 0.8),
        ("key", b"a"), ("idle", 0.4), ("type", "call mum"), ("idle", 0.4), ("key", b"\r"), ("idle", 1.0),
        ("key", b"d"), ("idle", 1.0),            # delete "call mum"; the selection moves up to "write the docs"
        ("key", b" "), ("idle", 1.2),            # mark it done
        ("key", b"q"), ("idle", 1.0),            # quit: the list stays in the scrollback
    ],
    "step3-streaming": [
        ("wait", "❯ "), ("idle", 1.2),
        ("type", "what is termui?"), ("idle", 0.5), ("key", b"\r"),
        ("wait", "stays live."), ("idle", 2.0),
        ("key", b"\x03"),
    ],
    "step4-status": [
        ("wait", "❯ "), ("idle", 1.0),
        ("type", "what is termui?"), ("idle", 0.4), ("key", b"\r"),
        ("wait", "Responding"), ("idle", 0.7), ("key", b"\x1b"),   # Esc: stop this answer
        ("wait", "Interrupted"), ("idle", 1.2),
        ("type", "try again"), ("idle", 0.4), ("key", b"\r"),
        ("wait", "stays live."), ("idle", 1.8),
        ("key", b"\x03"),
    ],
    "step5-approval": [
        ("wait", "❯ "), ("idle", 1.0),
        ("type", "run the tests"), ("idle", 0.4), ("key", b"\r"),
        ("wait", "Allow Bash"), ("idle", 1.6), ("key", b"y"),
        ("wait", "12 passed"), ("idle", 1.2),
        ("type", "and again"), ("idle", 0.4), ("key", b"\r"),
        ("wait", "Allow Bash"), ("idle", 1.4), ("key", b"n"),
        ("wait", "denied by user"), ("idle", 1.5),
        ("key", b"\x03"),
    ],
}


class Emulator(pyte.Screen):
    """A screen that answers the cursor position request (ESC [ 6 n) the way a terminal does."""

    fd = None

    def report_device_status(self, mode):
        if mode == 6 and self.fd is not None:
            os.write(self.fd, f"\x1b[{self.cursor.y + 1};{self.cursor.x + 1}R".encode())
        else:
            super().report_device_status(mode)


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in SCRIPTS:
        sys.exit(f"usage: record.py <{'|'.join(SCRIPTS)}> [output-directory]")
    step = sys.argv[1]
    global COLS, ROWS
    COLS, ROWS = SIZES.get(step, (COLS, ROWS))
    out_dir = os.path.abspath(sys.argv[2] if len(sys.argv) > 2 else os.path.join(HERE, "..", "..", "site", "public", "casts"))
    step_dir = os.path.normpath(os.path.join(HERE, ELSEWHERE.get(step, step)))
    jars = [f for f in os.listdir(os.path.join(step_dir, "target", "bin"))] if os.path.isdir(os.path.join(step_dir, "target", "bin")) else []
    if not jars:
        sys.exit(f"build {step} first: (cd {step_dir} && bal build)")
    jar = os.path.join(step_dir, "target", "bin", jars[0])

    workdir = tempfile.mkdtemp(prefix="record-")
    env = dict(os.environ, TERM="xterm-256color", COLUMNS=str(COLS), LINES=str(ROWS))
    pid, fd = pty.fork()
    if pid == 0:
        fcntl.ioctl(0, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
        os.chdir(workdir)
        os.execvpe(JAVA, [JAVA, "-jar", jar], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    screen = Emulator(COLS, ROWS)
    screen.fd = fd
    stream = pyte.ByteStream(screen)
    events, seen, started = [], [b""], time.time()

    def pump(seconds=0.05):
        ready, _, _ = select.select([fd], [], [], seconds)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                return False
            if data:
                seen[0] += data
                stream.feed(data)
                events.append([round(time.time() - started, 4), "o", data.decode("utf-8", errors="replace")])
        return True

    def wait_for(text, timeout=60):
        mark = len(seen[0])
        end = time.time() + timeout
        while time.time() < end and text.encode() not in seen[0][mark:]:
            pump()
        if text.encode() not in seen[0][mark:]:
            sys.exit(f"timed out waiting for {text!r}")

    def idle(seconds):
        end = time.time() + seconds
        while time.time() < end:
            pump()

    for action, arg in SCRIPTS[step]:
        if action == "wait":
            wait_for(arg)
        elif action == "idle":
            idle(arg)
        elif action == "type":
            for ch in arg:
                os.write(fd, ch.encode())
                idle(0.07)
        elif action == "key":
            os.write(fd, arg)
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

    os.makedirs(out_dir, exist_ok=True)
    cast = os.path.join(out_dir, step + ".cast")
    with open(cast, "w") as f:
        f.write(json.dumps({"version": 2, "width": COLS, "height": ROWS, "timestamp": 0,
                            "env": {"TERM": "xterm-256color", "SHELL": "/bin/sh"}}) + "\n")
        for event in events:
            f.write(json.dumps(event) + "\n")
    shutil.rmtree(workdir, ignore_errors=True)
    print(f"wrote {cast} ({events[-1][0]:.1f} s)")


main()
