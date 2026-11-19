// Copyright (c) 2026, Ayesh Almeida.
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing,
// software distributed under the License is distributed on an
// "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND,
// either express or implied. See the License for the specific
// language governing permissions and limitations under the License.

import ayesha/termui.render;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/lang.runtime;

# An application. The runtime calls `update` for each message, one at a time and always on the same
# strand, and `view` to draw the live region after a batch of messages. Both may use and change the
# program's own fields freely: nothing else touches them.
public type Program object {
    # Handles one message.
    #
    # + message - a key press, a paste, a resize, an effect result, a tick, or any message the program sent.
    #             The first message is always a `term:ResizeEvent` with the size the program is drawn with, so
    #             the width is known from the first `view`; later resizes arrive the same way
    # + return - what to do next, or `()` for nothing
    public function update(Message message) returns Command?;

    # The live region for the current state, one entry per row.
    #
    # + return - the lines of styled text
    public function view() returns text:Span[][];
};

# How a program is run.
#
# + colors - whether to write color sequences
# + reflow - whether the terminal re-wraps text when it is resized (see `render:InlineRenderer`)
# + anchorBottom - whether to keep the live region on the last rows of the terminal, using the blank rows
#                  above it before the screen scrolls (see `render:InlineRenderer`); off by default, and
#                  ignored when `interactive` is `false`
# + pollInterval - the shortest time in seconds the loop sleeps when there is nothing to do; it sleeps longer
#                  (up to `maxPollInterval`) when the program has been idle for a while
# + maxPollInterval - the longest time in seconds the loop sleeps. While nothing happens the sleep grows from
#                     `pollInterval` toward this ceiling and returns to `pollInterval` when something does
#                     (a key, an effect result, a message; not a tick of an `every` timer). A value at or below
#                     `pollInterval` turns this off. A message that arrives while the loop sleeps waits for the
#                     sleep to end, so the first key after a long pause can wait about this long; lower it for a
#                     snappier first key or raise it to idle even cheaper
# + interactive - whether a user can answer questions; when `false`, `confirm` and `choose` return
#                 their default or a `NoTerminal` error at once
# + initialCommand - a command to carry out before the first message, for example to start streaming
#                    from an agent
# + fallbackSize - the size to draw with, and to tell the program, when the terminal cannot report one
#                  (or reports zero, as a pseudo-terminal nobody sized does)
public type Options record {|
    boolean colors = true;
    boolean reflow = true;
    boolean anchorBottom = false;
    decimal pollInterval = 0.005;
    decimal maxPollInterval = 0.5;
    boolean interactive = true;
    Command? initialCommand = ();
    term:Size fallbackSize = {width: 80, height: 24};
|};

// Reads the terminal's input and turns each event into a message. Runs on its own strand because
// reading blocks.
isolated function inputLoop(term:Terminal terminal, Session session) {
    while !session.isStopped() {
        term:InputEvent|error? event = terminal.nextEvent();
        if event is () {
            session.send(inputEnded());
            return;
        }
        if event is error {
            session.send(inputFailed(event.message()));
            return;
        }
        session.send(event.cloneReadOnly());
    }
}

isolated function runEffect(EffectFunction effect, Session session) {
    error? outcome = effect(session);
    if outcome is error {
        session.send(effectFailed(outcome.message()));
    }
}

isolated function tickLoop(Session session, decimal interval, Message message) {
    while !session.isStopped() {
        runtime:sleep(interval);
        session.send(message);
    }
}

// The loop of a running program. Everything that changes the program or the screen happens in
// `step`, on one strand: apply every waiting message, carry out the commands they returned, and draw
// at most one frame.
class Engine {
    private final Program program;
    private final term:Terminal terminal;
    private final render:Renderer renderer;
    private final Queue queue;
    private final PromptBoard board;
    final Session session;
    private boolean quitting = false;
    private boolean drawn = false;
    private Command? initial = ();
    private term:Size? initialSize = ();
    private PromptRequest? prompt = ();
    private int promptSerial = 0;
    private int promptIndex = 0;
    private boolean stepWasActive = true;
    private text:Span[][]? lastFrame = ();
    private decimal? shortestTimer = ();
    private Message[] timerMessages = [];

    function init(Program program, term:Terminal terminal, render:Renderer renderer, boolean interactive = true) {
        self.program = program;
        self.terminal = terminal;
        self.renderer = renderer;
        self.queue = new MessageQueue();
        self.board = new;
        self.session = new Session(self.queue, self.board, interactive);
    }

    // Remembers the initial command and the size to tell the program (both handled by the first step) and
    // starts reading the terminal.
    function launch(Command? initial = (), term:Size? size = ()) {
        self.initial = initial;
        self.initialSize = size;
        _ = start inputLoop(self.terminal, self.session);
    }

    // Stops the sources and lets the effects know; no message is delivered after this.
    function stop() {
        self.session.stop();
    }

    function hasQuit() returns boolean {
        return self.quitting;
    }

    // Whether the last step found something other than timer ticks to do: the first frame, the initial size or
    // command, a message that is not a tick of an `every` timer, or a question being asked or answered. The loop
    // goes back to its shortest sleep after such a step and sleeps longer after one that was not.
    function wasActive() returns boolean {
        return self.stepWasActive;
    }

    // The longest the loop may sleep: the ceiling asked for, lowered so that the ticks of the program's fastest
    // timer are handled within half their period.
    function ceiling(decimal maxInterval, decimal base) returns decimal {
        decimal? timer = self.shortestTimer;
        if timer is decimal {
            decimal cap = timer / 2;
            return cap < base ? base : (cap < maxInterval ? cap : maxInterval);
        }
        return maxInterval;
    }

    function step() returns boolean|error {
        boolean changed = !self.drawn;
        boolean active = !self.drawn;
        boolean mustDraw = !self.drawn; // false only while the step handles nothing but quiet timer ticks
        // The size the program is drawn with is its first message. It goes straight to the program and not
        // through the queue: a key must not overtake it, and it is not a resize, so nothing is redrawn for it.
        term:Size? size = self.initialSize;
        self.initialSize = ();
        if size is term:Size {
            readonly & term:ResizeEvent told = {kind: "resize", width: size.width, height: size.height};
            check self.carryOut(self.program.update(told));
            changed = true;
            active = true;
            mustDraw = true;
        }
        Command? first = self.initial;
        self.initial = ();
        if first is Command {
            active = true;
            mustDraw = true;
        }
        check self.carryOut(first);
        foreach Message message in self.queue.takeAll() {
            if !self.isTimerTick(message) {
                active = true;
                mustDraw = true;
            }
            boolean isResize = message is term:ResizeEvent;
            if isResize {
                term:ResizeEvent resized = <term:ResizeEvent>message;
                check self.renderer.resize(resized.width, resized.height);
                changed = true;
            }
            if self.answerPrompt(message) {
                changed = true;
                mustDraw = true;
                continue;
            }
            Command? command = self.program.update(message);
            if command is Command {
                mustDraw = true;
            }
            check self.carryOut(command);
            changed = true;
            if self.quitting {
                break; // messages after a quit are dropped, but the final state is still drawn
            }
        }
        if self.syncPrompt() {
            changed = true;
            active = true;
            mustDraw = true;
        }
        if changed {
            text:Span[][] frame = self.frame();
            // a tick that changed nothing is not worth a draw: it costs milliseconds and the screen is already right
            if mustDraw || frame != self.lastFrame {
                check self.renderer.draw(frame);
                self.drawn = true;
                self.lastFrame = frame;
            }
        }
        self.stepWasActive = active;
        return !self.quitting;
    }

    // Whether a message is the tick of one of the program's `every` timers (an equal message is treated as one).
    private function isTimerTick(Message message) returns boolean {
        foreach Message tick in self.timerMessages {
            if tick == message {
                return true;
            }
        }
        return false;
    }

    // Carries out a command. Commits are written at once, in the order the messages were handled, so
    // output the program writes itself (a result on standard output) and committed output keep the
    // order of the messages that caused them, however the messages happened to be batched.
    private function carryOut(Command? command) returns error? {
        if command is () {
            return;
        }
        if command is Quit {
            self.quitting = true;
        } else if command is Effect {
            _ = start runEffect(command.run, self.session);
        } else if command is Every {
            self.timerMessages.push(command.message);
            decimal? known = self.shortestTimer;
            if known is () || command.interval < known {
                self.shortestTimer = command.interval;
            }
            _ = start tickLoop(self.session, command.interval, command.message);
        } else if command is Batch {
            foreach Command each in command.commands {
                check self.carryOut(each);
            }
        } else if command is CommitProse {
            check self.renderer.commitProse(command.paragraphs);
        } else {
            check self.renderer.commitBlock(command.lines);
        }
    }

    // The program's view, with the question being asked (if any) below it.
    private function frame() returns text:Span[][] {
        text:Span[][] lines = self.program.view();
        PromptRequest? request = self.prompt;
        if request is PromptRequest {
            if request.kind == "confirm" {
                string hint = request.defaultAnswer is () ? "(y/n)" : request.defaultAnswer == true ? "(Y/n)" : "(y/N)";
                lines.push([{text: string `? ${request.question} ${hint}`, style: {bold: true}}]);
            } else {
                lines.push([{text: "? " + request.question, style: {bold: true}}]);
                foreach int index in 0 ..< request.options.length() {
                    string marker = index == self.promptIndex ? "> " : "  ";
                    lines.push([{text: marker + request.options[index]}]);
                }
            }
        }
        return lines;
    }

    // Shows a question that an effect has asked, and forgets it once it is answered.
    private function syncPrompt() returns boolean {
        [int, PromptRequest]? current = self.board.current();
        if current is [int, PromptRequest] && current[0] != self.promptSerial {
            self.promptSerial = current[0];
            self.prompt = current[1];
            self.promptIndex = 0;
            return true;
        }
        if current is () && self.prompt is PromptRequest {
            self.prompt = ();
            return true;
        }
        return false;
    }

    // While a question is shown, key presses answer it instead of reaching the program. Returns whether
    // the message was used.
    private function answerPrompt(Message message) returns boolean {
        PromptRequest? request = self.prompt;
        if request is () || !(message is term:KeyEvent) {
            return false;
        }
        term:KeyEvent event = <term:KeyEvent>message;
        if request.kind == "confirm" {
            if event.key == "y" || event.key == "Y" {
                self.finishPrompt(1);
            } else if event.key == "n" || event.key == "N" || event.key == "escape" {
                self.finishPrompt(0);
            } else if event.key == "enter" && request.defaultAnswer is boolean {
                self.finishPrompt(request.defaultAnswer == true ? 1 : 0);
            }
        } else {
            if event.key == "up" && self.promptIndex > 0 {
                self.promptIndex -= 1;
            } else if event.key == "down" && self.promptIndex < request.options.length() - 1 {
                self.promptIndex += 1;
            } else if event.key == "enter" {
                self.finishPrompt(self.promptIndex);
            } else if event.key == "escape" {
                self.finishPrompt(-1);
            }
        }
        return true;
    }

    private function finishPrompt(int answer) {
        self.board.resolve(answer);
        self.prompt = ();
    }
}

// The size to draw with: what the terminal says, unless it cannot say or reports nothing usable (a
// pseudo-terminal nobody sized reports 0 by 0), in which case the fallback is used.
isolated function usableSize(term:Size|error reported, term:Size fallback) returns term:Size {
    if reported is term:Size && reported.width > 0 && reported.height > 0 {
        return reported;
    }
    return fallback;
}

# Runs a program on a terminal until it asks to quit.
#
# The terminal is acquired first and always released afterwards, also when the program fails. Input,
# resizes, timers, and effects arrive as messages through one queue; the loop applies all that are
# waiting, then draws one frame.
#
# + program - the application
# + terminal - the terminal to use
# + options - how to run
# + renderer - what draws the program; an `InlineRenderer` on the terminal when absent (pass a
#              `PlainRenderer` for output that is not an interactive terminal)
# + return - an error when the terminal cannot be used or drawing fails
public function run(Program program, term:Terminal terminal, Options options = {}, render:Renderer? renderer = ()) returns error? {
    check terminal.acquire();
    error? failure = ();
    Engine? engine = ();
    do {
        term:Size size = usableSize(terminal.size(), options.fallbackSize);
        render:Renderer drawing = renderer ?: new render:InlineRenderer(terminal, size.width, size.height, options.colors, options.reflow,
            options.anchorBottom && options.interactive);
        Engine running = new (program, terminal, drawing, options.interactive);
        engine = running;
        running.launch(options.initialCommand, size);
        decimal interval = options.pollInterval;
        int emptyChecks = 0;
        while check running.step() {
            if running.wasActive() {
                interval = options.pollInterval;
                emptyChecks = 0;
            } else {
                [interval, emptyChecks] = backOff(interval, emptyChecks, options.pollInterval,
                    running.ceiling(options.maxPollInterval, options.pollInterval));
            }
            runtime:sleep(interval);
        }
        check drawing.close();
    } on fail error cause {
        failure = cause;
    }
    Engine? finished = engine;
    if finished is Engine {
        finished.stop();
    }
    error? released = terminal.release();
    if failure is error {
        return failure;
    }
    return released;
}
