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

import ballerina/os;
import ballerina/test;

// Runs `command` attached to a freshly allocated pseudo-terminal, using Python's `pty` module so the
// behavior is the same on macOS and Linux, and returns everything the command printed.
function runInPty(string command) returns string|error {
    os:Process process = check os:exec({
        value: "python3",
        arguments: ["-c", "import pty,sys; pty.spawn(['sh','-c',sys.argv[1]])", command]
    });
    byte[] output = check process.output();
    _ = check process.waitForExit();
    return string:fromBytes(output);
}

// Sample of the `tty` test group: these tests need a real terminal, so they are skipped unless the
// group is requested with `-Pgroups=tty`.
@test:Config {groups: ["tty"]}
function testPseudoTerminalIsAvailable() returns error? {
    string output = check runInPty("test -t 0 && test -t 1 && echo tty-ok");
    test:assertTrue(output.includes("tty-ok"), "stdin and stdout should be a terminal inside the pty");
}
