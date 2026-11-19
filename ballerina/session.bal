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

import ballerina/lang.runtime;

# A question a user is being asked.
#
# + kind - `confirm` for yes or no, `select` for one of several options
# + question - the question
# + options - the options of a `select`
# + defaultAnswer - the answer chosen by Enter in a `confirm`; none when absent
type PromptRequest record {|
    "confirm"|"select" kind;
    string question;
    string[] options = [];
    boolean? defaultAnswer = ();
|};

// Passes one question at a time from an effect (which waits) to the loop (which shows it and reads the
// answer). Answers are integers: 1 or 0 for a confirm, the chosen index or -1 for a select.
isolated class PromptBoard {
    private PromptRequest? active = ();
    private int serial = 0;
    private boolean answered = false;
    private int answerValue = 0;
    private boolean closed = false;

    isolated function ask(PromptRequest & readonly request) returns int|error {
        while true {
            lock {
                if self.closed {
                    return error("the program has ended");
                }
                if self.active is () {
                    self.active = request.clone();
                    self.serial += 1;
                    self.answered = false;
                    break;
                }
            }
            runtime:sleep(0.005);
        }
        while true {
            lock {
                if self.answered {
                    self.active = ();
                    return self.answerValue;
                }
                if self.closed {
                    return error("the program has ended");
                }
            }
            runtime:sleep(0.005);
        }
    }

    // The question being asked and not yet answered, with a number that changes for each question.
    isolated function current() returns [int, PromptRequest]? {
        lock {
            PromptRequest? request = self.active;
            if request is PromptRequest && !self.answered {
                return [self.serial, request.clone()];
            }
        }
        return ();
    }

    isolated function resolve(int value) {
        lock {
            self.answerValue = value;
            self.answered = true;
        }
    }

    isolated function close() {
        lock {
            self.closed = true;
        }
    }
}

# What an effect uses to talk to the program: send messages, and ask the user a question.
#
# An effect runs on its own strand and cannot touch the program's state; everything it produces goes
# through `send`. Messages must be immutable (the `Message` type requires it), so a mutable value is
# rejected when the code is compiled.
public isolated class Session {
    private final Queue queue;
    private final PromptBoard board;
    private final boolean interactive;
    private boolean stopped = false;

    isolated function init(Queue queue, PromptBoard board, boolean interactive = true) {
        self.queue = queue;
        self.board = board;
        self.interactive = interactive;
    }

    # Sends a message to the program. After the program has ended, messages are dropped.
    #
    # + message - the message
    public isolated function send(Message message) {
        boolean dropped = false;
        lock {
            dropped = self.stopped;
        }
        if !dropped {
            self.queue.push(message);
        }
    }

    # Whether the program has ended. Long-running effects should check it and stop.
    #
    # + return - `true` once the program has ended
    public isolated function isStopped() returns boolean {
        lock {
            return self.stopped;
        }
    }

    isolated function stop() {
        lock {
            self.stopped = true;
        }
        self.board.close();
    }

    # Asks the user a yes or no question and waits for the answer. The question appears in the live
    # region; `y`, `n`, Enter (the default, when there is one) and Esc (no) answer it.
    #
    # When nobody can answer (input is not a terminal) it does not wait: it returns the default when
    # there is one, and a `NoTerminal` error otherwise.
    #
    # + question - the question
    # + defaultAnswer - the answer chosen by Enter, and the answer used when there is no terminal;
    #                   `()` for none
    # + return - the answer, a `NoTerminal` error, or an error when the program ends first
    public isolated function confirm(string question, boolean? defaultAnswer = ()) returns boolean|error {
        if !self.interactive {
            if defaultAnswer is boolean {
                return defaultAnswer;
            }
            return noTerminal(question);
        }
        PromptRequest request = {kind: "confirm", question, options: [], defaultAnswer};
        int answer = check self.board.ask(request.cloneReadOnly());
        return answer == 1;
    }

    # Asks the user to pick one of several options and waits (named `choose` because `select` is
    # reserved). Up and Down move, Enter chooses, Esc cancels.
    #
    # When nobody can answer it does not wait: it returns `defaultChoice` when there is one, and a
    # `NoTerminal` error otherwise.
    #
    # + question - the question
    # + options - the options
    # + defaultChoice - the index used when there is no terminal; `()` for none
    # + return - the index of the chosen option, a `NoTerminal` error, or an error when the user
    #            cancels or the program ends
    public isolated function choose(string question, string[] options, int? defaultChoice = ()) returns int|error {
        if !self.interactive {
            if defaultChoice is int && defaultChoice >= 0 && defaultChoice < options.length() {
                return defaultChoice;
            }
            return noTerminal(question);
        }
        PromptRequest request = {kind: "select", question, options: options.clone(), defaultAnswer: ()};
        int answer = check self.board.ask(request.cloneReadOnly());
        if answer < 0 {
            return error("the user cancelled the question");
        }
        return answer;
    }
}
