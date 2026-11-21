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

// Step 1 of the to-do list tutorial: the counter becomes a list you move through. CI builds and tests this file.

import ayesha/termui;
import ayesha/termui.term;
import ayesha/termui.text;

type Item record {|
    string text;
    boolean done = false;
|};

class TodoList {
    *termui:Program;

    Item[] items;
    int selected = 0;

    function init(Item[] items = []) {
        self.items = items;
    }

    public function update(termui:Message message) returns termui:Command? {
        if message is termui:InputEnded {
            return termui:quit();
        }
        if message is term:KeyEvent {
            if message.key == "up" {
                self.selected = int:max(self.selected - 1, 0);
            } else if message.key == "down" {
                self.selected = int:min(self.selected + 1, self.items.length() - 1);
            } else if message.key == "q" {
                return termui:quit();
            }
        }
        return;
    }

    public function view() returns text:Span[][] {
        text:Span[][] lines = [];
        foreach int i in 0 ..< self.items.length() {
            boolean current = i == self.selected;
            lines.push([
                {text: current ? "> " : "  "},
                {text: self.items[i].text, style: {bold: current}}
            ]);
        }
        lines.push([{text: "up/down move   q quit", style: {dim: true}}]);
        return lines;
    }
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new TodoList([{text: "buy milk"}, {text: "write the docs"}, {text: "call mum"}]));
}
