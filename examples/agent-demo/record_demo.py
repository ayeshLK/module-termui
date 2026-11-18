#!/usr/bin/env python3
"""Records the README demo: the real agent demo, run three ways, composed into an asciicast and a GIF.

Usage: JAVA=/path/to/java25/bin/java python3 record_demo.py [output-directory]   (after `bal build`)
Needs `agg` (https://github.com/asciinema/agg) to render the GIF; the .cast is written either way.
"""
import fcntl, json, os, pty, select, shutil, struct, subprocess, sys, tempfile, termios, time

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.abspath(sys.argv[1] if len(sys.argv) > 1 else os.path.join(HERE, "..", "..", "docs", "assets"))
JAVA = os.environ.get("JAVA", "java")
JAR = os.path.join(HERE, "target", "bin", "agent_demo.jar")
COLS, ROWS = 84, 18
PROMPT = "\x1b[1;32m$\x1b[0m "

events = []
clock = 0.0


def emit(text, at=None):
    events.append([round(clock if at is None else at, 4), "o", text])


def pause(seconds):
    global clock
    clock += seconds


def type_line(text, comment=False):
    """A shell line typed by a person: a prompt, then one character at a time."""
    global clock
    emit(PROMPT if not comment else "\x1b[2m")
    for ch in text:
        emit(ch)
        clock += 0.035 if ch != " " else 0.06
    emit("\x1b[0m\r\n" if comment else "\r\n")
    pause(0.35)


def run(shell_command, pace_ms, answer_after=None):
    """Runs a command in a pty and records everything it prints, as it was printed."""
    global clock
    env = dict(os.environ, AGENT_DEMO_PACE_MS=str(pace_ms), TERM="xterm-256color", COLUMNS=str(COLS), LINES=str(ROWS))
    pid, fd = pty.fork()
    if pid == 0:
        os.execvpe("sh", ["sh", "-c", shell_command], env)
    fcntl.ioctl(fd, termios.TIOCSWINSZ, struct.pack("HHHH", ROWS, COLS, 0, 0))
    started = time.time()
    base = clock
    seen = b""
    answered = answer_after is None
    answer_at = None
    while True:
        ready, _, _ = select.select([fd], [], [], 0.02)
        if ready:
            try:
                data = os.read(fd, 65536)
            except OSError:
                break
            if not data:
                break
            seen += data
            emit(data.decode("utf-8", errors="replace"), base + (time.time() - started))
        if not answered and answer_after.encode() in seen and answer_at is None:
            answer_at = time.time() + 1.4          # a person reads the question, then answers
        if answer_at and not answered and time.time() >= answer_at:
            os.write(fd, b"y")
            answered = True
    try:
        os.waitpid(pid, 0)
    except ChildProcessError:
        pass
    clock = base + (time.time() - started)
    pause(0.9)


def main():
    work = tempfile.mkdtemp()
    app = f"'{JAVA}' -jar '{JAR}'"
    result = os.path.join(work, "result.txt")

    emit("\x1b[2J\x1b[H")
    pause(0.4)
    type_line("# an agent-style app: streamed text, a live status line, and an approval prompt", comment=True)
    type_line("agent-demo")
    run(app, 70, answer_after="(y/N)")

    pause(0.5)
    type_line("# the same program with its output redirected: the UI stays on the terminal,", comment=True)
    type_line("# and only the result goes to the file", comment=True)
    type_line("agent-demo > result.txt")
    run(f"{app} > '{result}'", 25, answer_after="(y/N)")
    type_line("cat result.txt")
    emit(open(result).read().replace("\n", "\r\n"))
    pause(1.0)

    type_line("# and in a script or CI: plain text, no questions asked, the same bytes every run", comment=True)
    type_line("agent-demo < /dev/null")
    run(f"{app} < /dev/null", 25)
    pause(1.6)

    os.makedirs(OUT, exist_ok=True)
    cast = os.path.join(OUT, "demo.cast")
    with open(cast, "w") as f:
        f.write(json.dumps({"version": 2, "width": COLS, "height": ROWS, "timestamp": 0,
                            "env": {"TERM": "xterm-256color", "SHELL": "/bin/sh"}}) + "\n")
        for event in events:
            f.write(json.dumps(event) + "\n")
    print(f"wrote {cast} ({clock:.1f} s)")
    if shutil.which("agg"):
        gif = os.path.join(OUT, "demo.gif")
        subprocess.run(["agg", "--quiet", "--font-size", "16", "--theme", "monokai", "--idle-time-limit", "1.5",
                        "--fps-cap", "20", cast, gif], check=True)
        print(f"wrote {gif} ({os.path.getsize(gif) // 1024} KB)")
    else:
        print("agg not found: install it to render the GIF")


main()
