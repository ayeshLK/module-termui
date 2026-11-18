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

@test:Config {}
function testShellQuoteEscapesSingleQuotes() {
    test:assertEquals(shellQuote("plain"), "'plain'");
    test:assertEquals(shellQuote("a'b"), "'a'\\''b'");
}

@test:Config {}
function testOnlyTerminalDevicesAreAccepted() {
    UnixTerminal terminal = new ("/etc/passwd");
    test:assertTrue(terminal.acquire() is error);
    test:assertTrue(terminal.write("x") is error);
}

@test:Config {groups: ["tty"]}
function testAcquireSwitchesToRawModeAndReleaseRestores() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "snapshot", label: "before"},
        {op: "wait", file: "acquired"},
        {op: "snapshot", label: "raw"},
        {op: "wait", file: "released"},
        {op: "snapshot", label: "after"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check waitFor(dir, "done-before");
    check terminal.acquire();
    test:assertTrue(terminal.acquire() is error, "a second acquire must fail");
    check touch(dir, "acquired");
    check waitFor(dir, "done-raw");
    check terminal.release();
    check terminal.release(); // releasing twice is safe
    check touch(dir, "released");
    map<json> result = check finishHelper(helper, dir);

    test:assertTrue(check snapshotFlag(result, "before", "icanon"));
    test:assertTrue(check snapshotFlag(result, "before", "echo"));
    test:assertFalse(check snapshotFlag(result, "raw", "icanon"), "raw mode turns line editing off");
    test:assertFalse(check snapshotFlag(result, "raw", "echo"), "raw mode turns echo off");
    test:assertFalse(check snapshotFlag(result, "raw", "isig"), "raw mode turns signal keys off");
    test:assertFalse(check snapshotFlag(result, "raw", "opost"), "raw mode turns output processing off");
    test:assertEquals(check snapshotAll(result, "after"), check snapshotAll(result, "before"),
            "release must restore every saved setting");
}

function failingWork(UnixTerminal terminal) returns error? {
    check terminal.acquire();
    do {
        fail error("work failed");
    } on fail error cause {
        check terminal.release();
        return cause;
    }
}

@test:Config {groups: ["tty"]}
function testTheTerminalIsRestoredWhenTheWorkFails() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "snapshot", label: "before"},
        {op: "wait", file: "failed"},
        {op: "snapshot", label: "after"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check waitFor(dir, "done-before");
    error? outcome = failingWork(terminal);
    test:assertTrue(outcome is error, "the work error must reach the caller");
    check touch(dir, "failed");
    map<json> result = check finishHelper(helper, dir);
    test:assertEquals(check snapshotAll(result, "after"), check snapshotAll(result, "before"));
}

@test:Config {groups: ["tty"]}
function testSizeIsReadFromTheTerminal() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "resize", rows: 30, cols: 100},
        {op: "touch", file: "resized"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check waitFor(dir, "resized");
    test:assertEquals(check terminal.size(), <Size>{width: 100, height: 30});
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);
}

@test:Config {groups: ["tty"]}
function testWritesReachTheTerminalWithoutOutputProcessing() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "written"},
        {op: "drain", label: "out", seconds: 0.5},
        {op: "touch", file: "drained"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check terminal.write("a\nb");
    check touch(dir, "written");
    check waitFor(dir, "drained");
    check terminal.release();
    check touch(dir, "finished");
    map<json> result = check finishHelper(helper, dir);
    string out = check drained(result, "out");
    // the first bytes are the bracketed-paste switch from acquire, then the frame exactly as written
    test:assertTrue(out.endsWith("a\nb"), "raw mode must not turn a line feed into CR LF: " + out);
    test:assertFalse(out.includes("\r"), "no carriage return may be added");
}

function expectEvent(UnixTerminal terminal, InputEvent expected) returns error? {
    InputEvent|error? event = terminal.nextEvent();
    test:assertEquals(event, expected);
}

@test:Config {groups: ["tty"]}
function testInputIsDecodedFromTheTerminal() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "send", hex: "61"},
        {op: "send", hex: "e697a5"},
        {op: "send", hex: "03"},
        {op: "send", hex: "1b5b41"},
        {op: "send", hex: "1b5b313b3543"},
        {op: "send", hex: "1b5b3230307e68690a1b5b3230317e"},
        {op: "send", hex: "1b"},
        {op: "wait", file: "escape-seen"},
        {op: "send", hex: "1b5b"},
        {op: "sleep", seconds: 0.01},
        {op: "send", hex: "41"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");

    check expectEvent(terminal, <KeyEvent>{key: "a"});
    check expectEvent(terminal, <KeyEvent>{key: "日"});
    // Ctrl+C is a key in raw mode, not a signal: the process is still running to read it
    check expectEvent(terminal, <KeyEvent>{key: "c", ctrl: true});
    check expectEvent(terminal, <KeyEvent>{key: "up"});
    check expectEvent(terminal, <KeyEvent>{key: "right", ctrl: true});
    check expectEvent(terminal, <PasteEvent>{text: "hi\n"});
    // a lone Esc is reported as the Escape key once nothing follows it
    check expectEvent(terminal, <KeyEvent>{key: "escape"});
    check touch(dir, "escape-seen");
    // a sequence split across two writes, a few milliseconds apart, is still one key
    check expectEvent(terminal, <KeyEvent>{key: "up"});

    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);
}

@test:Config {groups: ["tty"]}
function testABurstOfInputLosesNothing() returns error? {
    string dir = check newWorkDir();
    string burst = "";
    foreach int _ in 0 ..< 300 {
        burst += "61";
    }
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "send", hex: burst},
        {op: "send", hex: "1b5b42"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    foreach int _ in 0 ..< 300 {
        check expectEvent(terminal, <KeyEvent>{key: "a"});
    }
    check expectEvent(terminal, <KeyEvent>{key: "down"});
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);
}
