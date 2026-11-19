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

// Helpers shared by the tests of this step: building events, reading what a program draws, and a terminal
// that answers a question when a person would.

import ayesha/termui;
import ayesha/termui.term;
import ballerina/lang.runtime;

// region events
function typed(string:Char c) returns readonly & term:KeyEvent {
    return {kind: "key", key: c, ctrl: false, alt: false};
}

function enter() returns readonly & term:KeyEvent {
    return {kind: "key", key: "enter", ctrl: false, alt: false};
}

function escape() returns readonly & term:KeyEvent {
    return {kind: "key", key: "escape", ctrl: false, alt: false};
}

// Types a question into the program by calling update directly, the way the runtime would.
function ask(Chat chat, string question) returns termui:Command? {
    foreach string:Char c in question {
        _ = chat.update(typed(c));
    }
    return chat.update(enter());
}
// endregion events

// region rows
// The text of the live region, one string per row.
function rows(Chat chat) returns string[] {
    string[] result = [];
    foreach var line in chat.view() {
        string row = "";
        foreach var span in line {
            row += span.text;
        }
        result.push(row);
    }
    return result;
}
// endregion rows

// region gated-terminal
// A terminal that gives the program its scripted keys, and then holds back one more key (the answer to a
// question) until the screen shows the question. A key pushed up front would reach the program before the
// question existed; this one arrives when a person's would.
isolated class GatedTerminal {
    *term:Terminal;

    private final term:FakeTerminal inner;
    private final string waitFor;
    private final string:Char answer;
    private boolean given = false;

    isolated function init(term:FakeTerminal inner, string waitFor, string:Char answer) {
        self.inner = inner;
        self.waitFor = waitFor;
        self.answer = answer;
    }

    public isolated function acquire() returns error? {
        return self.inner.acquire();
    }

    public isolated function release() returns error? {
        return self.inner.release();
    }

    public isolated function size() returns term:Size|error {
        return self.inner.size();
    }

    public isolated function write(string data) returns error? {
        return self.inner.write(data);
    }

    public isolated function nextEvent() returns term:InputEvent|error? {
        term:InputEvent|error? event = self.inner.nextEvent();
        if event is () {
            boolean alreadyGiven = false;
            lock {
                alreadyGiven = self.given;
                self.given = true;
            }
            if !alreadyGiven {
                foreach int _ in 0 ..< 1000 {
                    if self.inner.screenText().includes(self.waitFor) {
                        break;
                    }
                    runtime:sleep(0.01);
                }
                return {kind: "key", key: self.answer};
            }
        }
        return event;
    }
}
// endregion gated-terminal
