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

# A terminal the application draws on and reads input from.
#
# There is a Unix implementation that drives a real terminal and an in-memory `FakeTerminal` for tests
# and non-interactive use. `nextEvent` blocks, so an implementation must not hold a lock while it
# waits: other strands call `write` and `size` at the same time.
public type Terminal isolated object {
    # Takes the terminal over (raw input mode for a real terminal). Fails if it is already acquired.
    #
    # + return - an error when the terminal cannot be acquired
    public isolated function acquire() returns error?;

    # Gives the terminal back and restores its original settings. Safe to call more than once.
    #
    # + return - an error when the settings cannot be restored
    public isolated function release() returns error?;

    # The current size of the terminal.
    #
    # + return - the size, or an error when it cannot be determined
    public isolated function size() returns Size|error;

    # Waits for the next input event.
    #
    # + return - the event, `()` when the input has ended, or an error when reading fails
    public isolated function nextEvent() returns InputEvent|error?;

    # Writes output to the terminal as a single write, so a whole frame is never shown in pieces.
    #
    # + data - the text, including any escape sequences
    # + return - an error when the write fails
    public isolated function write(string data) returns error?;
};
