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

// Used by the "Testing without a terminal" page of the documentation site: a tiny prompt that echoes
// what is typed, small enough to test completely against a fake terminal.

import ayesha/termui;
import ayesha/termui.term;
import ayesha/termui.text;

// region echo
class Echo {
    *termui:Program;

    string typed = "";

    public function update(termui:Message message) returns termui:Command? {
        if message is term:KeyEvent {
            if message.key == "enter" {
                string line = self.typed;
                self.typed = "";
                return termui:commitProse([[{text: "you said: " + line}]]);
            }
            if message.key == "!" {
                return termui:quit();
            }
            if message.key is string:Char && !message.ctrl {
                self.typed += message.key;
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "> " + self.typed}]];
    }
}
// endregion echo
