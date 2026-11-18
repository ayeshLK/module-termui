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

function runPython(string code, string argument) returns string|error {
    os:Process process = check os:exec({value: "python3", arguments: ["-c", code, argument]});
    byte[] output = check process.output();
    _ = check process.waitForExit();
    return string:fromBytes(output);
}

@test:Config {}
function testRedirectedOutputIsNotATerminal() {
    Environment env = environmentFrom({}, true, false, true);
    test:assertFalse(env.stdoutIsTerminal);
    test:assertFalse(env.colorEnabled, "no color when stdout is not a terminal");
}

@test:Config {}
function testColorOnForATerminal() {
    test:assertTrue(environmentFrom({TERM: "xterm-256color"}, true, true, true).colorEnabled);
    test:assertTrue(environmentFrom({}, true, true, true).colorEnabled);
}

@test:Config {}
function testNoColorTurnsColorOff() {
    test:assertFalse(environmentFrom({NO_COLOR: "1"}, true, true, true).colorEnabled);
    // an empty value does not count, as in the no-color.org convention
    test:assertTrue(environmentFrom({NO_COLOR: ""}, true, true, true).colorEnabled);
}

@test:Config {}
function testDumbTerminalTurnsColorOff() {
    Environment env = environmentFrom({TERM: "dumb"}, true, true, true);
    test:assertTrue(env.dumbTerminal);
    test:assertFalse(env.colorEnabled);
}

@test:Config {}
function testSizeFromTheEnvironment() {
    Environment env = environmentFrom({COLUMNS: "132", LINES: "50"}, true, true, true);
    test:assertEquals([env.width, env.height], [132, 50]);
    Environment unknown = environmentFrom({COLUMNS: "wide", LINES: "-3"}, true, true, true);
    test:assertEquals([unknown.width, unknown.height], [DEFAULT_WIDTH, DEFAULT_HEIGHT]);
    test:assertEquals([DEFAULT_WIDTH, DEFAULT_HEIGHT], [80, 24]);
}

@test:Config {}
function testProbeOutputIsParsed() {
    test:assertEquals(parseStdioProbe("0 /dev/ttys006\n1 /private/tmp/out\n2 /dev/pts/3\n"), [true, false, true]);
    test:assertEquals(parseStdioProbe("0 /dev/tty1\r\n1 /dev/console\r\n2 /dev/tty\r\n"), [true, true, true]);
    test:assertEquals(parseStdioProbe("0 \n1 pipe:[1234]\n2 /dev/null\n"), [false, false, false]);
    test:assertEquals(parseStdioProbe("garbage\n9 /dev/tty1\nx y\n"), [false, false, false]);
    test:assertEquals(parseStdioProbe(""), [false, false, false]);
}

@test:Config {}
function testDetectionNeverFails() {
    Environment env = detectEnvironment();
    test:assertTrue(env.width > 0 && env.height > 0);
}

// The probe runs in a child of the process under test. Here that process is a Python program whose
// standard streams are pipes, so none of them may be reported as a terminal.
@test:Config {}
function testProbeSeesPipesAsNotATerminal() returns error? {
    string code = "import subprocess, sys\nsys.stdout.write(subprocess.run(['sh', '-c', sys.argv[1]], capture_output=True, text=True).stdout)";
    string output = check runPython(code, STDIO_PROBE_SCRIPT);
    test:assertEquals(parseStdioProbe(output), [false, false, false], output);
}

// The same probe run from a Python program that owns a pseudo-terminal must see all three as terminals.
@test:Config {groups: ["tty"]}
function testProbeSeesAPseudoTerminal() returns error? {
    string code = string `import os, pty, subprocess, sys
pid, fd = pty.fork()
if pid == 0:
    out = subprocess.run(['sh', '-c', sys.argv[1]], capture_output=True, text=True).stdout
    sys.stdout.write(out)
    sys.stdout.flush()
    os._exit(0)
data = b''
while True:
    try:
        chunk = os.read(fd, 4096)
    except OSError:
        break
    if not chunk:
        break
    data += chunk
os.waitpid(pid, 0)
sys.stdout.write(data.decode())`;
    string output = check runPython(code, STDIO_PROBE_SCRIPT);
    test:assertEquals(parseStdioProbe(output), [true, true, true], output);
}

@test:Config {}
function testModeFollowsTheStandardStreams() {
    test:assertEquals(selectMode(environmentFrom({}, true, true, true)), "interactive");
    test:assertEquals(selectMode(environmentFrom({}, true, false, true)), "pipedOutput");
    test:assertEquals(selectMode(environmentFrom({}, false, true, true)), "pipedInput");
    test:assertEquals(selectMode(environmentFrom({}, false, false, false)), "headless");
}
