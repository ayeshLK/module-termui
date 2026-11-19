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

// Step 3 of the documentation site tutorial: a streamed answer. The prompt from step 2 now starts an
// effect that streams the scripted model's answer back as messages. CI builds and tests this file.

import ayesha/termui;
import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;

class Chat {
    *termui:Program;

    private input:LineEditor editor = new;
    private int width = 80;
    // region state
    private final decimal delay;      // pause between pieces of the answer
    private boolean busy = false;     // an answer is streaming
    private int turn = 0;             // which question the answer belongs to
    private string partial = "";      // the line being written, not finished yet
    private boolean quitWhenIdle = false;
    // endregion state

    function init(decimal delay = 0.03) {
        self.delay = delay;
    }

    public function update(termui:Message message) returns termui:Command? {
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
        // region stream-messages
        if message is Token && message.turn == self.turn {
            return self.onToken(message.text);
        }
        if message is Done && message.turn == self.turn {
            return self.onDone();
        }
        if message is termui:EffectFailed {
            // the effect returned an error (a real model call can fail): say so and take input again
            self.busy = false;
            self.partial = "";
            return termui:commitProse([[{text: "error: " + message.reason, style: {fg: "red"}}]]);
        }
        // endregion stream-messages
        if message is term:KeyEvent|term:PasteEvent {
            return self.onInput(message);
        }
        return;
    }

    private function onInput(term:KeyEvent|term:PasteEvent message) returns termui:Command? {
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

    // region ask
    private function ask(string question) returns termui:Command {
        self.busy = true;
        self.turn += 1;
        self.partial = "";
        return termui:batch([
            termui:commitProse([[{text: "❯ " + question, style: {bold: true}}]]),
            termui:effect(streamAnswer(self.turn, question, self.delay))
        ]);
    }
    // endregion ask

    // region fold
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

    private function onDone() returns termui:Command? {
        termui:Command[] commands = [];
        if self.partial != "" {
            commands.push(termui:commitBlock([[{text: self.partial}]]));
        }
        commands.push(termui:commitProse([[]]));
        self.partial = "";
        self.busy = false;
        if self.quitWhenIdle {
            commands.push(termui:quit());
        }
        return termui:batch(commands);
    }
    // endregion fold

    // region view
    public function view() returns text:Span[][] {
        text:Span[][] lines = [];
        if self.partial != "" {
            lines.push([{text: self.partial}]);
        }
        foreach text:Span[] row in self.editor.render(self.width, "❯ ") {
            lines.push(row);
        }
        return lines;
    }
    // endregion view
}

// region main
public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new Chat(), anchorBottom = true);
}
// endregion main
