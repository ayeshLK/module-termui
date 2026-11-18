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

# Where messages wait until the loop applies them. The loop is the only reader; any strand may push.
# It is an interface so the mechanism can change (for example from polling to a blocking queue)
# without touching the loop.
public type Queue isolated object {
    # Adds a message to the end.
    #
    # + message - the message
    isolated function push(Message message);

    # Removes and returns every waiting message, oldest first. Never waits.
    #
    # + return - the messages
    isolated function takeAll() returns Message[];
};

# The standard queue: a lock-guarded list.
isolated class MessageQueue {
    *Queue;

    private Message[] items = [];

    isolated function push(Message message) {
        lock {
            self.items.push(message);
        }
    }

    isolated function takeAll() returns Message[] {
        lock {
            Message[] all = self.items.clone();
            self.items = [];
            return all.clone();
        }
    }
}
