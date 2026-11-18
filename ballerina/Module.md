## Overview

The runtime that turns a program into a running terminal application. A program is an object with two
methods, and the runtime does the rest.

```
 keys, resizes, timers, effect results ---> [ message queue ] ---> loop ---> update(message) ---> command
                                                                      |
                                                                      +--> view() --> one frame per batch
```

- **`Program`** has `update(message)`, called once per message, and `view()`, which returns the lines
  of the live region.
- **`run`** acquires the terminal, runs the loop until the program returns `quit()`, and always releases
  the terminal afterwards, also when something fails.
- **Messages** are immutable values (`Message`): key, paste, and resize events, the results of effects,
  timer ticks, and any message of your own.
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
