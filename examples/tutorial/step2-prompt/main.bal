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

// Step 2 of the documentation site tutorial: a prompt. The counter's state becomes a LineEditor, and a
// submitted line is committed above the prompt. CI builds and tests this file.

import ayesha/termui;
import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;

class Prompt {
    *termui:Program;

    // region state
    private input:LineEditor editor = new;
    private int width = 80;
    // endregion state

    // region update
    public function update(termui:Message message) returns termui:Command? {
        if message is term:ResizeEvent {
            self.width = message.width;
            return;
        }
        if message is termui:InputEnded {
            return termui:quit();
        }
        if message is term:KeyEvent|term:PasteEvent {
            input:EditResult result = self.editor.handleEvent(message);
            if result is input:Submitted {
                return termui:commitProse([[{text: "❯ " + result.text, style: {bold: true}}]]);
            }
            if result == "ignored" && message is term:KeyEvent && message.ctrl && message.key == "c" {
                return termui:quit();
            }
        }
        return;
    }
    // endregion update

    // region view
    public function view() returns text:Span[][] {
        return self.editor.render(self.width, "❯ ");
    }
    // endregion view
}

// region main
public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new Prompt());
}
// endregion main
