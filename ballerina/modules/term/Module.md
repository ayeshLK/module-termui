## Overview

The terminal the application draws on and reads input from.

- **`Terminal`** is the interface: `acquire`, `release`, `size`, `nextEvent` (blocks), and `write` (one
  write per frame). Input arrives as `KeyEvent`, `PasteEvent`, and `ResizeEvent` values.
- **`FakeTerminal`** is an in-memory implementation for tests and non-interactive use. Script input
  with `pushText`, `pushKey`, and `pushEvent`; read the result back with `screenLines`, `screenText`,
  `scrollbackLines`, and `cursorPosition`; check how it was written with `writes`.
- **`detectEnvironment`** reports whether standard input, output, and error are terminals and whether
  color may be used (`NO_COLOR`, `TERM=dumb`, and a non-terminal output all turn it off). It asks the
  operating system about its parent process, which costs one short `sh` process (about 25 ms), so call it
  once at startup. When the probe fails the streams are treated as not being terminals.

### Example

```ballerina
import ayesha/termui.term;

public function main() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    check terminal.write("hello\r\nworld");
    // terminal.screenText() == "hello\nworld"
}
```
