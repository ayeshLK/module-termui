## Overview

**Build agent-style terminal apps in Ballerina: streaming output, a live region, and approval prompts that stay well-behaved in pipes and CI.**

A small live region (a spinner, a status line, a prompt) is redrawn in place at the bottom of the
terminal, and finished output goes into your normal scrollback. The same program runs interactively,
with its output redirected, and with no terminal at all, and it can be tested without a terminal.
Your program's state lives on one strand; effects are `isolated` and report back with immutable
messages. It is a UI toolkit only: agent logic stays in your application.

> **Status: experimental (0.1).** The API can change before 1.0. macOS and Linux only. See the
> [repository](https://github.com/ayeshLK/module-termui) for a demo recording, examples and the design notes.

## Modules

| Module | What it is for |
|---|---|
| `ayesha/termui` | The runtime: `Program`, `run`, messages, commands, effects, prompts, and `Interface` |
| `ayesha/termui.term` | The terminal: `UnixTerminal`, `FakeTerminal`, `StreamTerminal`, input events, environment detection |
| `ayesha/termui.render` | Drawing: `InlineRenderer`, `PlainRenderer`, the cell buffer |
| `ayesha/termui.text` | Styled text, display width, and wrapping |

Each module's `Module.md` has the details.

## Stability

Everything documented in the module pages is supported API; symbols described there as low-level may
change in a minor release. `Renderer` and `Terminal` have a fixed set of required methods, and later
abilities arrive as separate optional capability types, so an implementation you write keeps working.
The run settings keep their defaults for the whole major version: colors and reflow on, bottom
anchoring off, interactive on.

## Running without a terminal

The same program works interactively, in a pipe, and in a script. `Interface` looks at what the process
is attached to and hands out the matching terminal, renderer, and options:

| Standard input | Standard output | Mode | What happens |
|---|---|---|---|
| terminal | terminal | `interactive` | The inline interface on the terminal. |
| terminal | redirected | `pipedOutput` | The interface is still drawn on the terminal. **Results go to standard output and nothing else does**, so the next program in the pipe gets clean data. |
| redirected | terminal | `pipedInput` | Plain text, no colors or cursor control. Nobody can answer questions. |
| redirected | redirected | `headless` | Plain text, as for `pipedInput`. |

- **Results.** `ui.result(text)` is for what a caller or a pipe is waiting for. With output redirected
  it writes a line to standard output and never to the terminal the interface is drawn on. When
  standard output is the terminal itself, it is committed above the live region like other finished
  output (writing to the terminal directly would corrupt the live region).
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

### Keeping the input at the bottom

By default the live region starts on the row where the program was started, so on a fresh screen the
prompt sits at the top. Pass `anchorBottom = true` and it stays on the last rows of the terminal, like a
chat input, while the blank rows above it are used for output before anything scrolls:

```ballerina
check ui.run(new Report(), anchorBottom = true);
```

It needs a terminal that reports its cursor position (most do; one that does not is drawn as without the
option) and has no effect when the output is not an interactive terminal. With `termui:run` directly, set
`anchorBottom` in `Options`. The details and limits are in the `termui.render` module's documentation.

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
