# Changelog

All notable changes to termui are listed here, newest first. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow the rules in
[COMPATIBILITY.md](COMPATIBILITY.md).

## [Unreleased]

## [1.0.0] - 2026-11-19

termui is stable. From this release the API follows [COMPATIBILITY.md](COMPATIBILITY.md): breaking
changes are made only in a new major version. The only API additions since 0.4.0 are the new option
`Options.maxPollInterval` and the matching optional parameters of `Interface` and `UnixTerminal`.

### Added
- **Idle backoff.** A program that is waiting for input now uses about 1% of a CPU core instead of about 10%:
  the engine loop and the terminal's input check sleep longer while nothing happens, from `pollInterval`
  (5 ms) up to the new `Options.maxPollInterval` (default 0.5 s), and go back to the short sleep as soon as a
  key, an effect result or another message arrives. `Interface` takes a `maxPollInterval` argument and passes it
  to the terminal it creates, and `UnixTerminal` takes one too. A value at or below `pollInterval` turns the
  backoff off. The median first key takes about 40 ms after a second of idleness, about 110 ms after three seconds
  and about half a second after more than 13 seconds.
- `bench/idle_cpu.py` and `bench/latency.py`, which measure the idle CPU and the first-key delay of a built program.
- `COMPATIBILITY.md`: what is public API, what each kind of release may change, how deprecation works,
  and the supported platforms.
- This changelog and a `SECURITY.md` with how to report a vulnerability.
- A release checklist in `CONTRIBUTING.md` and `examples/agent-harness/tmux_check.sh`, which runs the
  agent harness in tmux and checks the layout, editing keys, a resize and the approval prompts.

### Changed
- `Options.pollInterval` is now documented as the shortest sleep: the loop may sleep longer while idle (its default
  is unchanged).
- The ticks of an `every` timer do not end the backoff, the ceiling is lowered to half the period of the fastest
  timer, and a tick that leaves the view unchanged no longer redraws.
- A cursor position request reads its reply itself instead of waiting for the input loop, so it is answered in time
  while that loop sleeps.
- The README and `Package.md` describe the package as stable.
- Documented that a line of the live region wider than the terminal is cut off at the right edge, not
  wrapped (it has always behaved this way; wrap it first with `text:wrap`).
- `examples/agent-harness` uses the terminal width from the first message, so long input wraps under
  the prompt.

## [0.4.0] - 2026-11-19

### Added
- **The first message a program receives is the terminal size**, as a `term:ResizeEvent`, so the width
  is known before the first `view`. It is the terminal's size, or `Options.fallbackSize` when the
  terminal cannot report one. It is delivered in every mode, writes nothing to the terminal, and is
  followed by the usual resize events when the window changes.
- `Options.fallbackSize` (default 80 by 24): the size to draw with, and to tell the program, when the
  terminal reports none or zero. `Interface.options()` sets it from `COLUMNS` and `LINES`.

### Changed
- A program that counts or logs every message sees one more message at the start. Programs that
  ignore messages they do not know are unaffected.

## [0.3.0] - 2026-11-19

### Added
- **`ayesha/termui.input`**: `LineEditor`, a text input driven by key and paste events, with
  readline-style editing and cursor movement, word and line deletion, multi-line input (Alt+Enter or
  Ctrl+J for a line break), paste as one edit, a history of submissions, and `render` to draw it
  wrapped to a width with a visible cursor.
- A *Stability* section in every module page and in `Package.md`, and the extension rule: `Renderer`
  and `Terminal` have a fixed set of required methods and new abilities arrive as optional capability
  types.

### Removed
These were public by accident, were never documented as API, and are no longer public.

| Symbol | Instead |
|---|---|
| `ayesha/termui`: `Queue`, `PromptRequest` | none; use `Session.confirm` and `Session.choose` |
| `ayesha/termui.term`: `probeStdio`, `parseStdioProbe`, `isTerminalPath` | `detectEnvironment`, or `environmentFrom` to build an `Environment` in a test |
| `ayesha/termui.term`: `DEFAULT_WIDTH`, `DEFAULT_HEIGHT` | none; the defaults are 80 by 24 |

## [0.2.0] - 2026-11-18

### Added
- **Bottom anchoring**: `Options.anchorBottom` (and `anchorBottom` on `Interface.run` and
  `Interface.renderer`) keeps the live region on the last rows of the terminal, using the blank rows
  below the existing output before the screen scrolls. It needs a terminal that answers the cursor
  position request and has no effect otherwise.
- `term:CursorReporter` and `term:CursorPosition`: an optional terminal ability to report where the
  cursor is, implemented by `UnixTerminal` and `FakeTerminal`.
- The `examples/agent-harness` example, which replaces `examples/agent-demo`.

### Changed
- `Interface` sizes the renderer from the terminal itself, not from `COLUMNS` and `LINES`, which are
  only the fallback. A terminal that reports no usable size (a pseudo-terminal nobody sized) no longer
  stops the interface from drawing.

## [0.1.0] - 2026-11-18

First release.

### Added
- The runtime: `Program`, `run`, messages and commands (`quit`, `effect`, `every`, `commitProse`,
  `commitBlock`, `batch`), effects that report back with immutable messages, and prompts
  (`Session.confirm`, `Session.choose`).
- `Interface`: interactive, piped-output, piped-input and headless modes, with plain, repeatable output
  and no waiting for input that cannot come.
- `ayesha/termui.term` (`UnixTerminal`, `FakeTerminal`, `StreamTerminal`, input events, environment
  detection), `ayesha/termui.render` (`InlineRenderer`, `PlainRenderer`, the cell buffer) and
  `ayesha/termui.text` (styled text, display width, wrapping).
- The `examples/counter` and `examples/agent-demo` examples.

[Unreleased]: https://github.com/ayeshLK/module-termui/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/ayeshLK/module-termui/compare/v0.4.0...v1.0.0
[0.4.0]: https://github.com/ayeshLK/module-termui/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/ayeshLK/module-termui/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/ayeshLK/module-termui/compare/v0.1.0...v0.2.0
[0.1.0]: https://github.com/ayeshLK/module-termui/releases/tag/v0.1.0
