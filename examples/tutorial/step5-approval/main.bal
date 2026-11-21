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

// Step 5 of the documentation site tutorial: a tool call with approval. After its answer the scripted model
// asks to run a tool, and the effect waits for the user's yes or no. CI builds and tests this file.

import ayesha/termui;
import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;

const string[] SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

// Sent by the timer every 0.1 seconds.
type Tick record {|
    "tick" kind = "tick";
|};

class Chat {
    *termui:Program;

    private input:LineEditor editor = new;
    private int width = 80;
    private final decimal delay;      // pause between pieces of the answer
    private boolean busy = false;     // an answer is streaming
    private int turn = 0;             // which question the answer belongs to
    private string partial = "";      // the line being written, not finished yet
    private boolean quitWhenIdle = false;
    private int ticks = 0;            // one tick is 0.1 s
    private int turnStartTick = 0;
    private string statusText = "";
    private CancelFlag? cancel = ();  // set while an answer is streaming

    function init(decimal delay = 0.03) {
        self.delay = delay;
    }

    public function update(termui:Message message) returns termui:Command? {
        if message is Tick {
            self.ticks += 1;
            return;
        }
        if message is term:ResizeEvent {
            self.width = message.width;
            return;
        }
        if message is termui:InputEnded {
            if self.busy {
                self.quitWhenIdle = true; // let the answer finish first
                return;
            }
            return termui:quit();
        }
        if message is Status && message.turn == self.turn {
            self.statusText = message.text;
            return;
        }
        if message is ToolStarted && message.turn == self.turn {
            self.statusText = string `Running ${message.name}(${message.arg})`;
            return;
        }
        if message is ToolFinished && message.turn == self.turn {
            return self.onToolFinished(message);
        }
        if message is Token && message.turn == self.turn {
            return self.onToken(message.text);
        }
        if message is Done && message.turn == self.turn {
            return self.onDone(message.interrupted);
        }
        if message is termui:EffectFailed {
            self.busy = false;
            self.cancel = ();
            self.partial = "";
            return termui:commitProse([[{text: "error: " + message.reason, style: {fg: "red"}}]]);
        }
        if message is term:KeyEvent|term:PasteEvent {
            return self.onInput(message);
        }
        return;
    }

    private function onInput(term:KeyEvent|term:PasteEvent message) returns termui:Command? {
        if message is term:KeyEvent && message.key == "escape" {
            CancelFlag? flag = self.cancel;
            if self.busy && flag is CancelFlag {
                flag.cancel();
                self.statusText = "Interrupting";
            }
            return;
        }
        if self.busy && message is term:KeyEvent && message.key == "enter" {
            return; // keep what is typed until the answer is finished
        }
        input:EditResult result = self.editor.handleEvent(message);
        if result is input:Submitted {
            return self.ask(result.text);
        }
        if result == "ignored" && message is term:KeyEvent && message.ctrl && message.key == "c" {
            return termui:quit();
        }
        return;
    }

    private function ask(string question) returns termui:Command {
        CancelFlag flag = new;
        self.cancel = flag;
        self.busy = true;
        self.turn += 1;
        self.partial = "";
        self.turnStartTick = self.ticks;
        self.statusText = "Thinking";
        return termui:batch([
            termui:commitProse([[{text: "❯ " + question, style: {bold: true}}]]),
            termui:effect(streamAnswer(self.turn, question, self.delay, flag))
        ]);
    }

    private function onToolFinished(ToolFinished tool) returns termui:Command {
        text:Style markStyle = {fg: tool.ok ? "green" : "red"};
        return termui:commitBlock([
            [{text: "●", style: markStyle}, {text: " " + tool.name, style: {bold: true}}, {text: "(" + tool.arg + ")", style: {dim: true}}],
            [{text: "  ⎿  " + tool.summary, style: {dim: true}}]
        ]);
    }

    // Folds a piece into the line being written. Every line that is finished is committed.
    private function onToken(string piece) returns termui:Command? {
        self.partial += piece;
        termui:Command[] commands = [];
        int? newline = self.partial.indexOf("\n");
        while newline is int {
            commands.push(termui:commitBlock([[{text: self.partial.substring(0, newline)}]]));
            self.partial = self.partial.substring(newline + 1);
            newline = self.partial.indexOf("\n");
        }
        return commands.length() == 0 ? () : termui:batch(commands);
    }

    private function onDone(boolean interrupted) returns termui:Command? {
        termui:Command[] commands = [];
        if self.partial != "" {
            commands.push(termui:commitBlock([[{text: self.partial}]]));
        }
        if interrupted {
            commands.push(termui:commitProse([[{text: "⏹ Interrupted", style: {fg: "yellow"}}]]));
        }
        commands.push(termui:commitProse([[]]));
        self.partial = "";
        self.busy = false;
        self.cancel = ();
        if self.quitWhenIdle {
            commands.push(termui:quit());
        }
        return termui:batch(commands);
    }

    public function view() returns text:Span[][] {
        text:Span[][] lines = [];
        if self.partial != "" {
            lines.push([{text: self.partial}]);
        }
        if self.busy {
            string frame = SPINNER[self.ticks % SPINNER.length()];
            int seconds = (self.ticks - self.turnStartTick) / 10;
            // while a question is shown, keys answer it, so Esc is not "interrupt" then
            string hint = self.statusText == "Waiting for approval" ? "answer below" : "esc to interrupt";
            lines.push([
                {text: frame + " " + self.statusText + "… ", style: {fg: "brightCyan"}},
                {text: string `(${seconds}s · ${hint})`, style: {dim: true}}
            ]);
        }
        foreach text:Span[] row in self.editor.render(self.width, "❯ ") {
            lines.push(row);
        }
        return lines;
    }
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    // the timer ticks every 0.1 s for the spinner and the elapsed time
    check ui.run(new Chat(), termui:every(0.1, {kind: "tick"}), anchorBottom = true);
}
