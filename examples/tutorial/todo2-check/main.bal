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

// Step 2 of the to-do list tutorial: check things off and delete them. CI builds and tests this file.

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
            string key = message.key;
            if key == "up" {
                self.selected = int:max(self.selected - 1, 0);
            } else if key == "down" {
                self.selected = int:min(self.selected + 1, self.items.length() - 1);
            } else if key == " " && self.items.length() > 0 {
                self.items[self.selected].done = !self.items[self.selected].done;
            } else if key == "d" && self.items.length() > 0 {
                _ = self.items.remove(self.selected);
                self.selected = int:max(int:min(self.selected, self.items.length() - 1), 0);
            } else if key == "q" {
                return termui:quit();
            }
        }
        return;
    }

    public function view() returns text:Span[][] {
        text:Span[][] lines = [];
        foreach int i in 0 ..< self.items.length() {
            Item item = self.items[i];
            boolean current = i == self.selected;
            lines.push([
                {text: current ? "> " : "  "},
                {text: item.done ? "[x] " : "[ ] ", style: {dim: item.done}},
                {text: item.text, style: {dim: item.done, bold: current}}
            ]);
        }
        if self.items.length() == 0 {
            lines.push([{text: "Nothing to do.", style: {dim: true}}]);
        }
        lines.push([{text: "up/down move   space done   d delete   q quit", style: {dim: true}}]);
        return lines;
    }
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new TodoList([{text: "buy milk"}, {text: "write the docs"}, {text: "call mum"}]));
}
