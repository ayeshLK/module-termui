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

import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/test;

// A program that is only a prompt: the editor takes the keys, Ctrl+C quits, and what was submitted is kept.
class PromptProgram {
    *Program;

    input:LineEditor editor = new;
    string[] submitted = [];

    public function update(Message message) returns Command? {
        if message is term:KeyEvent && message.ctrl && message.key == "c" {
            return quit();
        }
        if message is term:KeyEvent|term:PasteEvent {
            input:EditResult result = self.editor.handleEvent(message);
            if result is input:Submitted {
                self.submitted.push(result.text);
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return self.editor.render(20);
    }
}

@test:Config {}
function testTypingPastingAndSubmittingInARunningProgram() returns error? {
    term:FakeTerminal terminal = new (30, 6);
    terminal.pushText("hi");
    terminal.pushEvent({kind: "paste", text: " there"});
    terminal.pushKey("enter");
    terminal.pushText("two");
    terminal.pushKey("enter");
    terminal.pushKey("up");
    terminal.pushKey("up");
    terminal.pushKey("down");
    terminal.pushKey("escape"); // not the editor's: it reports "ignored" and the program may act on it
    terminal.pushEvent({kind: "key", key: "c", ctrl: true});
    PromptProgram program = new;
    check run(program, terminal);
    test:assertEquals(program.submitted, ["hi there", "two"]);
    test:assertEquals(program.editor.text(), "two", "Up, Up, Down walked the history to the newer entry");
    test:assertTrue(terminal.screenLines()[0].startsWith("> two"), terminal.screenLines()[0]);
}

@test:Config {}
function testALineBreakThenSubmitInAProgram() returns error? {
    term:FakeTerminal terminal = new (30, 8);
    terminal.pushKey("enter", alt = true);
    terminal.pushText("b");
    terminal.pushKey("enter");
    terminal.pushEvent({kind: "key", key: "c", ctrl: true});
    PromptProgram program = new;
    check run(program, terminal);
    test:assertEquals(program.submitted, ["\nb"]);
    test:assertEquals(program.editor.text(), "");
    string[] rows = terminal.screenLines();
    test:assertTrue(rows[0].startsWith(">"), "the editor is drawn from the first row");
}

// Mirrors the example in modules/input/Module.md; if this changes, update the documentation to match.
class DocPrompt {
    *Program;

    input:LineEditor editor = new (history = ["hello"]);
    int width = 80;

    public function update(Message message) returns Command? {
        if message is term:ResizeEvent {
            self.width = message.width; // the first message is the size, so the width is known from the first view
        }
        if message is term:KeyEvent|term:PasteEvent {
            input:EditResult result = self.editor.handleEvent(message);
            if result is input:Submitted {
                return commitProse([[{text: "you said: " + result.text}]]);
            }
            if result == "ignored" && message is term:KeyEvent && message.ctrl && message.key == "c" {
                return quit();
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return self.editor.render(self.width);
    }
}

@test:Config {}
function testModuleDocExampleForTheLineEditor() returns error? {
    term:FakeTerminal terminal = new (40, 6);
    terminal.pushKey("up");
    terminal.pushText("!");
    terminal.pushKey("enter");
    terminal.pushEvent({kind: "key", key: "c", ctrl: true});
    check run(new DocPrompt(), terminal);
    test:assertTrue(terminal.screenText().includes("you said: hello!"), terminal.screenText());
}

@test:Config {}
function testTheEditorWrapsToTheWidthTheProgramWasTold() returns error? {
    term:FakeTerminal terminal = new (12, 6);
    terminal.pushText("abcdefghijkl");
    terminal.pushEvent({kind: "key", key: "c", ctrl: true});
    DocPrompt program = new;
    check run(program, terminal);
    test:assertEquals(program.width, 12, "the width came from the first message");
    test:assertEquals(program.editor.render(program.width).length(), 2, "12 columns minus the prompt leave 10, so 12 characters take two rows");
}
