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

// Used by the "Strands and isolation" page of the documentation site: one slow job, done two ways.
// A timer ticks every 50 ms and on the fifth tick the program starts half a second of work. The program
// records when it handled each tick, so a test can see how long the interface went unresponsive.

import ayesha/termui;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/lang.runtime;
import ballerina/time;

const decimal TICK = 0.05;
const decimal WORK = 0.5;

class Job {
    *termui:Program;

    // true: do the work inside update. false: do it in an effect.
    final boolean blocking;
    decimal[] handledAt = [];
    int ticks = 0;
    string status = "idle";

    function init(boolean blocking) {
        self.blocking = blocking;
    }

    public function update(termui:Message message) returns termui:Command? {
        if message is term:ResizeEvent {
            return termui:every(TICK, {kind: "tick"});
        }
        if message is map<anydata> && message["kind"] == "tick" {
            self.handledAt.push(<decimal>time:monotonicNow());
            self.ticks += 1;
            if self.ticks == 5 {
                return self.startWork();
            }
            if self.ticks == 25 {
                return termui:quit();
            }
        }
        if message is map<anydata> && message["kind"] == "worked" {
            self.status = "done";
        }
        return ();
    }

    // region start-work
    function startWork() returns termui:Command? {
        self.status = "working";
        if self.blocking {
            // Blocks the program's strand, and with it every message and every frame.
            runtime:sleep(WORK);
            self.status = "done";
            return ();
        }
        // Sleeps on its own strand and reports back, so the interface keeps running.
        return termui:effect(isolated function(termui:Session session) returns error? {
            runtime:sleep(WORK);
            session.send({kind: "worked"});
        });
    }
    // endregion start-work

    public function view() returns text:Span[][] {
        return [[{text: self.status}]];
    }

    // The longest time between two handled ticks: how long the interface went without answering.
    public function longestGap() returns decimal {
        decimal longest = 0;
        foreach int i in 1 ..< self.handledAt.length() {
            decimal gap = self.handledAt[i] - self.handledAt[i - 1];
            if gap > longest {
                longest = gap;
            }
        }
        return longest;
    }
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    check ui.run(new Job(false));
}
