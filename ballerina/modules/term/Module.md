## Overview

The terminal the application draws on and reads input from.

- **`Terminal`** is the interface: `acquire`, `release`, `size`, `nextEvent` (blocks), and `write` (one
  write per frame). Input arrives as `KeyEvent`, `PasteEvent`, and `ResizeEvent` values.
- **`UnixTerminal`** drives a real terminal on macOS and Linux (see below).
- **`FakeTerminal`** is an in-memory implementation for tests and non-interactive use. Script input
  with `pushText`, `pushKey`, and `pushEvent`; read the result back with `screenLines`, `screenText`,
  `scrollbackLines`, and `cursorPosition`; check how it was written with `writes`.
- **`CursorReporter`** is a `Terminal` that can also be asked where its cursor is (`queryCursor`), an optional
  capability. `FakeTerminal` and `UnixTerminal` implement it; a terminal that does not is treated as not
  knowing. Test for it with `terminal is term:CursorReporter`.
- **`detectEnvironment`** reports whether standard input, output, and error are terminals and whether
  color may be used (`NO_COLOR`, `TERM=dumb`, and a non-terminal output all turn it off). It asks the
  operating system about its parent process, which costs one short `sh` process (about 25 ms), so call it
  once at startup. When the probe fails the streams are treated as not being terminals.

### The Unix terminal

`UnixTerminal` works through `stty` and escape sequences, with no Java code.

- **Requirements.** macOS or Linux, `sh` and `stty` on the path, and a terminal device. It opens
  `/dev/tty` (the controlling terminal) unless you pass another device. Windows is not supported.
- **Acquire and release.** `acquire` saves the terminal settings and switches to raw mode: no echo, no
  line editing, no signal keys (Ctrl+C arrives as a key event), and no output processing, so a line feed
  moves down only and frames must use carriage return plus line feed. It also turns on bracketed paste
  and in-band resize reports. `release` restores the saved settings and is safe to call twice.
- **Restoring after termination.** The settings are restored on `release`, when you handle an error and
  call `release`, and when the process is stopped gracefully (SIGTERM, SIGINT, SIGHUP). SIGKILL cannot be
  handled and leaves the terminal raw. If the terminal has already gone away, `release` gives up after
  three seconds instead of blocking the exit. To recover from SIGKILL, type this and press Enter (the terminal shows no
  echo, so type it blind if needed):

  ```
  stty sane
  ```

- **Input.** `nextEvent` decodes keys with Ctrl, Alt, and Shift, arrows, navigation and function keys,
  UTF-8, and bracketed paste. A lone Esc is reported as the Escape key after 50 ms with nothing after
  it. After `release` the reader may take the first byte typed, because a blocked read cannot be
  cancelled; programs that exit after `release` are not affected.
- **Cursor position.** `queryCursor` writes `ESC [ 6 n` and waits up to 200 ms for the terminal's reply, which
  `nextEvent` picks out of the input, so `nextEvent` must be running on another strand (the runtime's input
  loop does this). It returns `()` when the terminal does not answer; after the first silence it returns `()`
  at once. The reply is only recognized while a request is outstanding, because `ESC [ 1 ; 5 R` is also the
  Ctrl+F3 key. Keys typed during the wait are not lost.
- **Resize.** Terminals that support in-band resize reports (DEC mode 2048) send an event as soon as the
  window changes. Otherwise the size is polled about once a second, which costs a short process each
  time (about 15 ms).
- **Output.** `write` goes to the terminal device, not to standard output, so redirecting standard output
  does not disturb the interface. Each call is one write; writing frames costs about a millisecond each.

### Asking for the cursor position

```ballerina
import ayesha/termui.term;

function cursorRow(term:Terminal terminal) returns int? {
    if terminal is term:CursorReporter {
        term:CursorPosition|error? position = terminal.queryCursor();
        if position is term:CursorPosition {
            return position.row; // counted from zero
        }
    }
    return (); // not offered, not answered, or failed: treat the position as unknown
}
```

### Example

```ballerina
import ayesha/termui.term;

public function main() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    check terminal.write("hello\r\nworld");
    // terminal.screenText() == "hello\nworld"
}
```
