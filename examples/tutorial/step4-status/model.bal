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

// The scripted "model" of the documentation site tutorial (steps 3 to 6). It is deliberately fake: it
// "thinks" for a moment, then answers every question with the same few lines, a few characters at a time,
// so the interface has something to show. To connect a real model, replace what `streamAnswer` does
// inside the effect; everything around it stays the same.

import ayesha/termui;
import ballerina/lang.runtime;

// region messages
// Every message carries the turn it belongs to, so a late message from an old turn is ignored.
type Status record {|
    "status" kind = "status";
    int turn;
    string text;
|};

type Token record {|
    "token" kind = "token";
    int turn;
    string text;
|};

type Done record {|
    "done" kind = "done";
    int turn;
    boolean interrupted;
|};
// endregion messages

// region cancel
// Shared between the program (which cancels) and the effect (which checks). It is `isolated`, so both
// strands may hold it.
isolated class CancelFlag {
    private boolean set = false;

    isolated function cancel() {
        lock {
            self.set = true;
        }
    }

    isolated function isCancelled() returns boolean {
        lock {
            return self.set;
        }
    }
}
// endregion cancel

isolated function answerTo(string question) returns string {
    return "You asked: " + question + "\n" +
        "This answer is streamed a few characters at a time.\n" +
        "Each finished line is committed to your scrollback, and the line being written stays live.";
}

isolated function chunks(string text, int size = 3) returns string[] {
    string[] pieces = [];
    string piece = "";
    int count = 0;
    foreach string:Char c in text {
        piece += c;
        count += 1;
        if count == size {
            pieces.push(piece);
            piece = "";
            count = 0;
        }
    }
    if piece != "" {
        pieces.push(piece);
    }
    return pieces;
}

// region stream-answer
// The effect: it runs on its own strand and reports back only with messages.
isolated function streamAnswer(int turn, string question, decimal delay, CancelFlag flag) returns termui:EffectFunction {
    return isolated function(termui:Session session) returns error? {
        session.send({kind: "status", turn, text: "Thinking"});
        runtime:sleep(delay * 40);
        session.send({kind: "status", turn, text: "Responding"});
        boolean interrupted = false;
        foreach string piece in chunks(answerTo(question)) {
            if flag.isCancelled() || session.isStopped() {
                interrupted = true;
                break;
            }
            session.send({kind: "token", turn, text: piece});
            runtime:sleep(delay);
        }
        session.send({kind: "done", turn, interrupted});
    };
}
// endregion stream-answer
