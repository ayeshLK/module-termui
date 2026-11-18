## Overview

`ayesha/termui` is a terminal UI toolkit for building polished, interactive, agent-style command-line
applications in Ballerina: an inline live region, committed scrollback, streaming output, and
non-blocking input. It is a UI toolkit only; agent logic stays in the application.

> This package is under development. Windows is not supported yet.

## Modules

| Module | What it is for |
|---|---|
| `ayesha/termui` | The runtime: `Program`, `run`, messages, commands, effects, prompts, and `Interface` |
| `ayesha/termui.term` | The terminal: `UnixTerminal`, `FakeTerminal`, `StreamTerminal`, input events, environment detection |
| `ayesha/termui.render` | Drawing: `InlineRenderer`, `PlainRenderer`, the cell buffer |
| `ayesha/termui.text` | Styled text, display width, and wrapping |

Each module's `Module.md` has the details.

## Running without a terminal

The same program works interactively, in a pipe, and in a script. `Interface` looks at what the process
is attached to and hands out the matching terminal, renderer, and options:

| Standard input | Standard output | Mode | What happens |
|---|---|---|---|
| terminal | terminal | `interactive` | The inline interface on the terminal. |
| terminal | redirected | `pipedOutput` | The interface is still drawn on the terminal. **Results go to standard output and nothing else does**, so the next program in the pipe gets clean data. |
| redirected | terminal | `pipedInput` | Plain text, no colors or cursor control. Nobody can answer questions. |
| redirected | redirected | `headless` | Plain text, as for `pipedInput`. |

- **Results.** `ui.result(text)` writes a line to standard output, never to the terminal the interface is
  drawn on. Use it for what a caller or a pipe is waiting for.
- **Questions.** Without a terminal, `session.confirm` and `session.choose` never wait: they return
  the default you gave, or a `NoTerminal` error when there is none. Decide in your program what
  "no answer" means, for example deny by default.
- **Plain output.** Committed output is written as lines with no styling, escape sequences, or carriage
  returns. The live region (a spinner, a status line) is not repeated: only its final state is written,
  once, when the program ends. Text is wrapped at the terminal width from `COLUMNS`, or 80 columns when
  it is unknown. Two runs with the same input produce identical bytes, as long as the program does not put
  timing-dependent content (an animation frame, a clock) in the live region: stop animating when
  `ui.interactive` is `false`.
- **Color.** `NO_COLOR` (set and not empty) and `TERM=dumb` turn color off, also on a terminal.

Detecting the environment costs one short process (about 25 ms), so do it once at startup.

### Example

```ballerina
import ayesha/termui;
import ayesha/termui.term;
import ayesha/termui.text;

class Report {
    *termui:Program;

    public function update(termui:Message message) returns termui:Command? {
        if message is termui:InputEnded {
            return termui:batch([
                termui:commitProse([[{text: "report ready"}]]),
                termui:quit()
            ]);
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "working..."}]];
    }
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new Report());
}
```

With neither input nor output on a terminal (`bal run < /dev/null > out.txt`), `out.txt` contains exactly:

```
report ready
working...
```
