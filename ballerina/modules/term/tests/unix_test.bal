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
import ballerina/lang.runtime;
import ballerina/os;
import ballerina/test;
import ballerina/time;

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
    // a sequence written in two parts is still one key (whether the two parts arrive in one read or two;
    // a gap longer than the Esc timeout would make it Escape, which the decoder unit tests cover)
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

@test:Config {groups: ["tty"]}
function testAResizeIsDetectedByPolling() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "resize", rows: 40, cols: 120},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    // no notification is sent here, so this arrives from the periodic size check
    check expectEvent(terminal, <ResizeEvent>{width: 120, height: 40});
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);
}

@test:Config {groups: ["tty"]}
function testNoResizeEventWhileTheSizeIsUnchanged() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "sleep", seconds: 2.5},
        {op: "send", hex: "61"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    // two size checks happen before the key arrives; neither may report a change
    check expectEvent(terminal, <KeyEvent>{key: "a"});
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);
}

@test:Config {groups: ["tty"]}
function testAnInBandResizeNotificationStopsPolling() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        // ESC [ 48 ; 30 ; 100 ; 0 ; 0 t
        {op: "send", hex: "1b5b34383b33303b3130303b303b3074"},
        {op: "wait", file: "notified"},
        // the real size changes, but the terminal has shown that it reports resizes itself, so nothing
        // may poll: the first event after this must be the key, not a resize
        {op: "resize", rows: 50, cols: 90},
        {op: "sleep", seconds: 2.5},
        {op: "send", hex: "61"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    check expectEvent(terminal, <ResizeEvent>{width: 100, height: 30});
    check touch(dir, "notified");
    check expectEvent(terminal, <KeyEvent>{key: "a"});
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);
}

// Frames are written whole and in order, including frames larger than the pty's buffer.
@test:Config {groups: ["tty"]}
function testLargeFramesArriveCompleteAndInOrder() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "drain", label: "out", until_file: "written"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    string row = "";
    foreach int _ in 0 ..< 200 {
        row += "x";
    }
    string frame = "";
    foreach int _ in 0 ..< 1000 {
        frame += row + "\r\n";
    }
    // 1000 rows of 200 columns: about 200 KB, far more than a pty holds
    check terminal.write("<<" + frame + ">>");
    check terminal.write("[second]");
    check touch(dir, "written");
    map<json> result = check finishAfterRelease(helper, dir, terminal);
    string out = check drained(result, "out");
    int begin = check out.indexOf("<<").ensureType();
    string body = out.substring(begin);
    test:assertTrue(body.startsWith("<<" + frame + ">>[second]"), "the frames must arrive complete and in order");
}

function finishAfterRelease(os:Process helper, string dir, UnixTerminal terminal) returns map<json>|error {
    check terminal.release();
    check touch(dir, "finished");
    return finishHelper(helper, dir);
}

// A loose floor, not a benchmark. It exists to catch pathological slowness in the write path (a flush
// per byte, work that grows with the square of the output), which would drop this to a handful of frames
// per second. Frames of a full 50x200 screen are written to a pty that another process drains, so the
// rate depends on how much CPU the machine gives both: about 1000 frames/s on a quiet laptop, 170 to 320
// with 22 busy processes, and 89 to 138 with 66, where a floor of 100 failed in 4 of 10 runs. 30 leaves
// room for a slow shared runner and still fails a real regression.
@test:Config {groups: ["tty"]}
function testWritingFramesIsFastEnough() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "drain", label: "out", until_file: "written"},
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    string row = "";
    foreach int _ in 0 ..< 200 {
        row += "y";
    }
    string frame = "\u{1b}[H";
    foreach int _ in 0 ..< 50 {
        frame += row + "\r\n";
    }
    int frames = 300;
    decimal startedAt = time:monotonicNow();
    foreach int _ in 0 ..< frames {
        check terminal.write(frame);
    }
    decimal seconds = time:monotonicNow() - startedAt;
    io:println(string `${frames} frames of ${frame.length()} bytes in ${seconds} s: ${<decimal>frames / seconds} frames/s`);
    check touch(dir, "written");
    _ = check finishAfterRelease(helper, dir, terminal);
    test:assertTrue(<decimal>frames / seconds > 30d, "writes are too slow for streaming output");
}

// The recovery command documented for a terminal left raw (after SIGKILL, for example) must work.
@test:Config {groups: ["tty"]}
function testSttySaneRecoversATerminalLeftRaw() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"},
        {op: "snapshot", label: "raw"},
        {op: "wait", file: "recovered"},
        {op: "snapshot", label: "sane"},
        {op: "wait", file: "finished"}
    ]);
    string tty = check helperTty(dir);
    UnixTerminal terminal = new (tty);
    check terminal.acquire();
    check touch(dir, "acquired");
    check waitFor(dir, "done-raw");
    // what a user would type after a crash left the terminal raw
    string _ = check shell("stty sane < " + shellQuote(tty));
    check touch(dir, "recovered");
    check waitFor(dir, "done-sane");
    check touch(dir, "finished");
    map<json> result = check finishHelper(helper, dir);
    test:assertFalse(check snapshotFlag(result, "raw", "icanon"));
    foreach string flag in ["icanon", "echo", "isig", "opost"] {
        test:assertTrue(check snapshotFlag(result, "sane", flag), "stty sane must turn " + flag + " back on");
    }
}

// Opening a terminal device that has gone away can block forever. Release runs in the graceful-stop
// hook, so it must give up instead of keeping the process alive.
@test:Config {groups: ["tty"]}
function testReleaseDoesNotHangWhenTheTerminalHasGoneAway() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "acquired"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    check touch(dir, "acquired");
    _ = check finishHelper(helper, dir); // the helper exits, and the pty with it
    decimal startedAt = time:monotonicNow();
    error? outcome = terminal.release();
    decimal seconds = time:monotonicNow() - startedAt;
    test:assertTrue(seconds < 10d, string `release took ${seconds} s`);
    // whether it succeeds or reports an error is up to the platform; it must come back, and only once
    test:assertTrue(outcome is () || outcome is error);
    test:assertEquals(terminal.release(), (), "a second release is a no-op");
}

// Collects the events a terminal produces until the key `q`, the way the runtime's input loop pumps them.
isolated class Collected {
    private InputEvent[] events = [];

    isolated function add(InputEvent event) {
        lock {
            self.events.push(event.clone());
        }
    }

    isolated function all() returns InputEvent[] {
        lock {
            return self.events.clone();
        }
    }
}

function pumpUntilQ(UnixTerminal terminal, Collected collected) {
    while true {
        InputEvent|error? event = terminal.nextEvent();
        if event is InputEvent {
            collected.add(event);
            if event is KeyEvent && event.key == "q" {
                return;
            }
        } else {
            return;
        }
    }
}

@test:Config {groups: ["tty"]}
function testTheCursorPositionIsReadFromTheTerminal() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "cpr", label: "asked", row: 7, col: 3},
        {op: "send", hex: "6b71"}, // "k", then "q" to end the pump
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    Collected collected = new;
    future<()> pump = start pumpUntilQ(terminal, collected);
    CursorPosition? position = check terminal.queryCursor();
    () _ = wait pump;
    check terminal.release();
    check touch(dir, "finished");
    map<json> result = check finishHelper(helper, dir);

    test:assertEquals(position, <CursorPosition>{row: 6, col: 2}, "the reply is one-based, the answer zero-based");
    string asked = check drained(result, "asked");
    test:assertTrue(asked.endsWith("\u{1b}[6n"), "the request ESC [ 6 n was written");
    test:assertEquals(collected.all(), [<KeyEvent>{key: "k"}, <KeyEvent>{key: "q"}], "the reply is not a key");
}

@test:Config {groups: ["tty"]}
function testASilentTerminalCostsOneTimeoutAndKeepsInput() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "cpr", label: "asked", silent: true},
        {op: "send", hex: "6b71"}, // typed while the request waits
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir));
    check terminal.acquire();
    Collected collected = new;
    future<()> pump = start pumpUntilQ(terminal, collected);
    time:Utc begin = time:utcNow();
    CursorPosition? first = check terminal.queryCursor();
    decimal firstTook = time:utcDiffSeconds(time:utcNow(), begin);
    begin = time:utcNow();
    CursorPosition? second = check terminal.queryCursor();
    decimal secondTook = time:utcDiffSeconds(time:utcNow(), begin);
    () _ = wait pump;
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);

    test:assertEquals(first, ());
    test:assertTrue(firstTook >= 0.19d, "a terminal that does not answer is waited for");
    test:assertEquals(second, ());
    test:assertTrue(secondTook < 0.05d, "an unsupported terminal is remembered");
    test:assertEquals(collected.all(), [<KeyEvent>{key: "k"}, <KeyEvent>{key: "q"}], "typed input survives the wait");
}

@test:Config {}
function testAnUnacquiredTerminalDoesNotKnowItsCursor() returns error? {
    UnixTerminal terminal = new ("/dev/tty");
    test:assertEquals(check terminal.queryCursor(), ());
}

// ---- idle backoff ---------------------------------------------------------------------------------

// Like `Collected`, with the time each event was delivered.
isolated class Timed {
    private [InputEvent, decimal][] events = [];

    isolated function add(InputEvent event) {
        decimal at = time:monotonicNow();
        lock {
            self.events.push([event.clone(), at]);
        }
    }

    isolated function all() returns [InputEvent, decimal][] {
        lock {
            return self.events.clone();
        }
    }
}

function pumpTimedUntilQ(UnixTerminal terminal, Timed collected) {
    while true {
        InputEvent|error? event = terminal.nextEvent();
        if event is InputEvent {
            collected.add(event);
            if event is KeyEvent && event.key == "q" {
                return;
            }
        } else {
            return;
        }
    }
}

@test:Config {groups: ["tty"]}
function testKeysAfterAPauseAreStillDeliveredInOrder() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "go1"},
        {op: "send", hex: "6b"}, // k, after the pause
        {op: "wait", file: "go2"},
        {op: "send", hex: "6a"}, // j, soon after the first
        {op: "wait", file: "go3"},
        {op: "send", hex: "71"}, // q ends the pump
        {op: "wait", file: "finished"}
    ]);
    UnixTerminal terminal = new (check helperTty(dir), 0.04);
    check terminal.acquire();
    Timed collected = new;
    future<()> pump = start pumpTimedUntilQ(terminal, collected);
    runtime:sleep(1.6); // long enough for the sleep to reach the 40 ms ceiling
    decimal firstAsked = time:monotonicNow();
    check touch(dir, "go1");
    runtime:sleep(0.3);
    decimal secondAsked = time:monotonicNow();
    check touch(dir, "go2");
    runtime:sleep(0.2);
    check touch(dir, "go3");
    () _ = wait pump;
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);

    [InputEvent, decimal][] got = collected.all();
    test:assertEquals(got.length(), 3);
    test:assertEquals(got[0][0], <KeyEvent>{key: "k"});
    test:assertEquals(got[1][0], <KeyEvent>{key: "j"});
    // The schedule itself is tested without timing (backoff_test.bal) and the engine's recovery too; here it is
    // enough that a key after the backoff is delivered, within a generous bound that a loaded runner can meet.
    test:assertTrue(got[0][1] - firstAsked <= 1.0d, string `the first key waited ${(got[0][1] - firstAsked).toString()} s`);
    test:assertTrue(got[1][1] - secondAsked <= 1.0d, string `the second key waited ${(got[1][1] - secondAsked).toString()} s`);
}

@test:Config {groups: ["tty"]}
function testTheCursorPositionIsAnsweredWhileTheInputLoopSleepsLong() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "cpr", label: "asked", row: 7, col: 3},
        {op: "send", hex: "71"}, // q ends the pump
        {op: "wait", file: "finished"}
    ]);
    // a ceiling far above the 0.2 s the request may take: after about 5 s the loop sleeps more than 0.25 s at a time
    UnixTerminal terminal = new (check helperTty(dir), 5.0);
    check terminal.acquire();
    Collected collected = new;
    future<()> pump = start pumpUntilQ(terminal, collected);
    runtime:sleep(5.5);
    time:Utc begin = time:utcNow();
    CursorPosition? position = check terminal.queryCursor();
    decimal took = time:utcDiffSeconds(time:utcNow(), begin);
    () _ = wait pump;
    check terminal.release();
    check touch(dir, "finished");
    _ = check finishHelper(helper, dir);

    test:assertEquals(position, <CursorPosition>{row: 6, col: 2}, "the reply is found although the input loop is asleep");
    test:assertTrue(took < 0.2d, string `the request took ${took.toString()} s`);
}
