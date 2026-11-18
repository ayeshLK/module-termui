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

import ayesha/termui;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/lang.runtime;

// A small agent-style program: it streams text token by token, shows a spinner and a status line in
// the live region, asks for approval before "running a tool", and prints its result on standard
// output. It runs interactively, with its output piped, and with no terminal at all.

const string[] SPINNER = ["|", "/", "-", "\\"];

class AgentDemo {
    *termui:Program;

    private final termui:Interface ui;
    private string current = "";
    private string status = "thinking";
    private int frame = 0;

    function init(termui:Interface ui) {
        self.ui = ui;
    }

    public function update(termui:Message message) returns termui:Command? {
        if message is term:KeyEvent {
            // Ctrl+C is a key in raw mode, not a signal
            if message.key == "c" && message.ctrl {
                return termui:quit();
            }
            return ();
        }
        if message is map<anydata> {
            anydata kind = message["kind"];
            if kind == "tick" {
                self.frame += 1;
            } else if kind == "token" {
                anydata token = message["text"];
                self.current += token is string ? token : "";
            } else if kind == "line" {
                string line = self.current;
                self.current = "";
                return termui:commitProse([[{text: line}]]);
            } else if kind == "status" {
                anydata text = message["text"];
                self.status = text is string ? text : self.status;
            } else if kind == "finished" {
                anydata approved = message["approved"];
                error? written = self.ui.result("approved=" + (approved == true).toString());
                if written is error {
                    return termui:quit();
                }
                return termui:batch([termui:commitProse([[{text: "done", style: {bold: true}}]]), termui:quit()]);
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        text:Span[][] lines = [];
        if self.current != "" {
            lines.push([{text: self.current}]);
        }
        lines.push([{text: SPINNER[self.frame % SPINNER.length()] + " ", style: {fg: "cyan"}}, {text: self.status, style: {dim: true}}]);
        return lines;
    }
}

isolated function say(termui:Session session, string sentence) {
    foreach string word in re ` `.split(sentence) {
        session.send({kind: "token", text: word + " "});
        runtime:sleep(0.02);
    }
    session.send({kind: "line"});
}

isolated function agent(termui:Session session) returns error? {
    say(session, "I looked at the project and found a failing test.");
    session.send({kind: "status", text: "waiting for approval"});
    // Without a terminal this returns the default (deny) at once instead of waiting.
    boolean approved = check session.confirm("Run `make test`?", false);
    session.send({kind: "status", text: approved ? "running tests" : "skipping tests"});
    say(session, approved ? "Running the tests now." : "Understood, I will not run anything.");
    session.send({kind: "finished", approved});
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new AgentDemo(ui), termui:batch([termui:effect(agent), termui:every(0.1, {kind: "tick"})]));
}
