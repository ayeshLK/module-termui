## Overview

The runtime that turns a program into a running terminal application. A program is an object with two
methods, and the runtime does the rest.

```
   keys, resizes, timers, effect results
                     |
                     v
   +-------> message queue --> loop --> update(message) --> command --+
   |                           |                                      |
   |                           +--> view() --> one frame per batch    |
   |                                                                  |
   +------ effects and timers send new messages ----------------------+
```

- **`Program`** has `update(message)`, called once per message, and `view()`, which returns the lines
  of the live region.
- **`run`** acquires the terminal, runs the loop until the program returns `quit()`, and always releases
  the terminal afterwards, also when something fails.
- **Messages** are immutable values (`Message`): key, paste, and resize events, the results of effects,
  timer ticks, and any message of your own. The first message is always a `term:ResizeEvent` with the
  size the program is drawn with (the terminal's, or `Options.fallbackSize` when it cannot say), so the
  width is known before the first `view`; later changes of the window arrive the same way.
- **Commands** are what `update` returns: `quit()`, `effect(...)`, `every(...)`, `commitProse(...)`,
  `commitBlock(...)`, or `batch(...)` of several.

### The ownership rule

`update` and `view` always run on one strand, and nothing else reads or writes the program's fields, so
a program can keep plain mutable state and widgets as ordinary fields without locks. Everything that
happens elsewhere (reading the keyboard, timers, long-running work) reaches the program only as a
message. The loop applies every waiting message, then draws **one** frame, so a burst of streamed
tokens costs one redraw. Committed output is written at once, in the order of the messages that
caused it, so output the program writes itself (a result on standard output) stays in the same order
however the messages were batched.

### Effects

`effect(run)` runs work on its own strand. The function must be `isolated`, so it cannot reach the
program's fields, and it talks to the program only through its `Session`: `session.send(message)` for
results (as many as it likes, so streaming works). Messages must be immutable. Passing a mutable
value to `send`, or a function that is not isolated to `effect`, is a compile error. After the program
has ended, `send` drops messages and `session.isStopped()` is `true`, so long effects should check it.
An effect that returns an error produces an `EffectFailed` message.

### Asking the user

From an effect, `session.confirm(question, defaultAnswer)` and `session.choose(question, options)` wait
for the user's answer. The question appears below the live region and, while it is shown, key presses
answer it instead of reaching the program (`y`, `n`, Enter for the default, Esc for no; Up, Down,
Enter, Esc for a choice). They return an error when the program ends first or the user cancels a choice.
(The method is `choose` because `select` is a reserved word.)

### Where the interface sits

`Options.anchorBottom` (and the `anchorBottom` parameter of `Interface.run`) keeps the live region on the last
rows of the terminal instead of where the program was started. It is off by default; see the `termui.render`
module for how it behaves and where it does not apply. It is ignored when `interactive` is `false`.

### Idle cost

The loop wakes to look for messages, since a Ballerina program cannot wait for "a key or a timer or a message"
at once. While nothing happens it wakes less and less often: it starts at `pollInterval` (5 ms), doubles the
sleep after every 20 checks that found nothing, and stops at `maxPollInterval` (0.5 s), which it reaches after
about 13 seconds of idleness. A key, an effect result or any message the program sent returns it to
`pollInterval` at once. A waiting program, such as the counter example, then uses about 1% of a CPU core
instead of about 10%.

- **The first key after a long pause waits for the current sleep to end**, in two hops (the terminal's input
  check, then this loop). Measured on the counter example, the median first key takes about 40 ms after a
  second of idleness, about 110 ms after three seconds, and about half a second after more than 13 seconds. Lower `maxPollInterval` (or pass
  `maxPollInterval` to `Interface`, which sets it for the terminal too) for a snappier first key, or set it at
  or below `pollInterval` to turn the backoff off.
- **Timers.** The ticks of a timer started with `every` do not end the backoff, and the ceiling is lowered to
  half the period of the program's fastest timer, so ticks are handled on time. A tick that leaves the view
  unchanged does not redraw. A program with a 100 ms timer idles at a few percent, mostly the work of its own
  `update` and `view` ten times a second.
- **Measuring.** `bench/idle_cpu.py` and `bench/latency.py` in the repository measure idle CPU and the first-key
  delay for any built program.

### Stability

The supported API of this module is `Program`, `run`, `Options`, `Interface`, `Session`, `Message`,
`Command` with its helpers (`quit`, `effect`, `commitProse`, `commitBlock`, `every`, `batch`) and the
message types the runtime sends. New messages and commands are added in minor releases, so handle the
ones you know and ignore the rest. The run settings keep their defaults for the whole major version:
`colors` and `reflow` on, `anchorBottom` off, `interactive` on, `pollInterval` 0.005 seconds and
`maxPollInterval` 0.5 seconds.

### Example

```ballerina
import ayesha/termui;
import ayesha/termui.term;
import ayesha/termui.text;

class Counter {
    *termui:Program;

    int count = 0;

    public function update(termui:Message message) returns termui:Command? {
        if message is term:KeyEvent {
            if message.key == "+" {
                self.count += 1;
            } else if message.key == "q" {
                return termui:quit();
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "count: " + self.count.toString()}]];
    }
}

public function main() returns error? {
    // a real application uses term:UnixTerminal; the fake terminal makes this checkable
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("++q");
    check termui:run(new Counter(), terminal);
    // terminal.screenText() == "count: 2"
}
```
