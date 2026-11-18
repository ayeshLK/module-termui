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

import ballerina/io;

# A terminal that can only be written to: standard output, standard error, or a file. It has no input
# (`nextEvent` returns `()` at once) and no raw mode, so it is what output that is not an interactive
# terminal is drawn on, usually together with `render:PlainRenderer`.
public isolated class StreamTerminal {
    *Terminal;

    private final io:FileOutputStream target;
    private final string? filePath;
    private final int width;
    private final int height;

    # + target - `io:stdout` or `io:stderr`, used when no file is given
    # + width - the width to report
    # + height - the height to report
    # + filePath - append to this file instead of a standard target (for tests and for tools that
    #              capture the output)
    public isolated function init(io:FileOutputStream target = io:stdout, int width = DEFAULT_WIDTH,
            int height = DEFAULT_HEIGHT, string? filePath = ()) {
        self.target = target;
        self.width = width;
        self.height = height;
        self.filePath = filePath;
    }

    # Nothing to take over.
    #
    # + return - always `()`
    public isolated function acquire() returns error? {
    }

    # Nothing to give back.
    #
    # + return - always `()`
    public isolated function release() returns error? {
    }

    # The size given when the terminal was created.
    #
    # + return - the size
    public isolated function size() returns Size|error {
        return {width: self.width, height: self.height};
    }

    # There is no input.
    #
    # + return - always `()`
    public isolated function nextEvent() returns InputEvent|error? {
        return ();
    }

    # Writes the data in one call.
    #
    # + data - the output
    # + return - an error when the write fails
    public isolated function write(string data) returns error? {
        string? path = self.filePath;
        if path is string {
            return io:fileWriteString(path, data, io:APPEND);
        }
        return io:fprint(self.target, data);
    }
}
