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

// Step 5 of the to-do list tutorial on the documentation site: the finished program, a to-do list that keeps
// its items in a file. CI builds and tests this file.

import ayesha/termui;
import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/file;
import ballerina/io;

type Item record {|
    string text;
    boolean done = false;
|};

class TodoList {
    *termui:Program;

    Item[] items;
    int selected = 0;
    boolean adding = false;
    boolean leaving = false;
    private input:LineEditor editor = new (multiline = false);

    function init(Item[] items = []) {
        self.items = items;
    }

    public function update(termui:Message message) returns termui:Command? {
        if message is termui:InputEnded {
            return termui:quit();
        }
        if message is term:KeyEvent|term:PasteEvent {
            return self.adding ? self.typing(message) : self.browsing(message);
        }
        return;
    }

    // Browsing: move, toggle, delete, start an add, or quit.
    function browsing(term:KeyEvent|term:PasteEvent message) returns termui:Command? {
        if message is term:PasteEvent {
            return;
        }
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
        } else if key == "a" {
            self.adding = true;
        } else if key == "q" {
            self.leaving = true;
            return termui:batch([termui:commitProse(self.summary()), termui:quit()]);
        }
        return;
    }

    // Adding: the line editor handles the keys; enter appends the item, escape gives up.
    function typing(term:KeyEvent|term:PasteEvent message) returns termui:Command? {
        input:EditResult result = self.editor.handleEvent(message);
        if result is input:Submitted {
            if result.text.trim() != "" {
                self.items.push({text: result.text.trim()});
                self.selected = self.items.length() - 1;
            }
            self.adding = false;
        } else if result == "ignored" && message is term:KeyEvent && message.key == "escape" {
            self.adding = false;
        }
        return;
    }

    public function view() returns text:Span[][] {
        if self.leaving {
            return []; // the list was committed to the scrollback, so draw nothing more
        }
        text:Span[][] lines = [];
        foreach int i in 0 ..< self.items.length() {
            Item item = self.items[i];
            boolean current = i == self.selected && !self.adding;
            lines.push([
                {text: current ? "> " : "  "},
                {text: item.done ? "[x] " : "[ ] ", style: {dim: item.done}},
                {text: item.text, style: {dim: item.done, bold: current}}
            ]);
        }
        if self.items.length() == 0 {
            lines.push([{text: "Nothing to do. Press a to add an item.", style: {dim: true}}]);
        }
        if self.adding {
            lines.push(...self.editor.render(60, "new: "));
        } else {
            lines.push([{text: "up/down move   space done   a add   d delete   q quit", style: {dim: true}}]);
        }
        return lines;
    }

    // The list as it is left in the scrollback when the program quits.
    function summary() returns text:Span[][] {
        if self.items.length() == 0 {
            return [[{text: "No items."}]];
        }
        return from Item item in self.items
            select [{text: (item.done ? "[x] " : "[ ] ") + item.text}];
    }
}

const string FILE_NAME = "todos.json";

function loadItems(string path = FILE_NAME) returns Item[]|error {
    if !check file:test(path, file:EXISTS) {
        return [];
    }
    json content = check io:fileReadJson(path);
    return content.cloneWithType();
}

function saveItems(Item[] items, string path = FILE_NAME) returns error? {
    check io:fileWriteJson(path, items.toJson());
}

public function main() returns error? {
    TodoList list = new (check loadItems());
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(list);
    check saveItems(list.items);
}
