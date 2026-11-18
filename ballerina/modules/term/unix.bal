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
import ballerina/time;

const string BRACKETED_PASTE_ON = "\u{1b}[?2004h";

// In-band resize notifications (DEC private mode 2048): terminals that support it send
// ESC [ 48 ; rows ; cols ; height ; width t whenever the window changes. (release switches both this
// and bracketed paste off again with printf, inside the same timed command that restores the settings.)
const string RESIZE_REPORTS_ON = "\u{1b}[?2048h";

// How often the size is polled while no in-band notification has ever been received. Each poll costs
// about 15 ms (a process spawn), so this stays coarse.
const decimal RESIZE_POLL_INTERVAL = 1;

// How long an Esc byte waits for the rest of a sequence before it is reported as the Escape key.
const decimal ESCAPE_TIMEOUT = 0.05;

// How long a cursor position request waits for the terminal's reply. Real terminals answer within a few
// milliseconds (the slowest measured was 16 ms); a terminal that never answers costs this once.
const decimal CURSOR_REPORT_TIMEOUT = 0.2;

const string CURSOR_POSITION_REQUEST = "\u{1b}[6n";

// Runs a shell command and returns what it printed; a non-zero exit status is an error.
isolated function shell(string script) returns string|error {
    os:Process process = check os:exec({value: "sh", arguments: ["-c", script]});
    byte[] output = check process.output();
    int status = check process.waitForExit();
    if status != 0 {
        return error(string `command failed with status ${status}: ${script}`);
    }
    return string:fromBytes(output);
}

// Like shell, but gives up after a number of seconds. Opening a terminal device that has gone away
// (a closed window, a vanished pty) can block forever, and a blocked graceful-stop hook would stop
// the process from ever exiting. The command runs in a background subshell that a timer kills.
isolated function shellWithin(string script, int seconds) returns string|error {
    string wrapped = string `( ${script} ) & job=$!; ( sleep ${seconds}; kill -9 $job 2>/dev/null ) >/dev/null 2>&1 & ` +
        string `timer=$!; wait $job; status=$?; kill $timer 2>/dev/null; exit $status`;
    return shell(wrapped);
}

// Reads the output of `stty size`: "rows columns".
isolated function parseSize(string output) returns Size|error {
    string[] parts = re ` `.split(output.trim());
    if parts.length() != 2 {
        return error(string `unexpected stty size output: ${output}`);
    }
    int rows = check int:fromString(parts[0]);
    int columns = check int:fromString(parts[1]);
    return {width: columns, height: rows};
}

isolated function shellQuote(string value) returns string {
    return "'" + re `'`.replaceAll(value, "'\\''") + "'";
}

# A real terminal on macOS or Linux, driven through `stty` and escape sequences.
#
# `acquire` puts the terminal into raw mode (no echo, no line editing, no signal keys, no output
# processing) and turns on bracketed paste; `release` restores the settings that were saved first.
# Because raw mode turns off output processing, a line feed moves down only, so frames must use
# carriage return plus line feed. Settings are also restored when the process is stopped gracefully
# (SIGTERM, SIGINT, SIGHUP); only SIGKILL leaves the terminal raw, and `stty sane` recovers it.
#
# Output goes to the terminal device itself, not to standard output, so redirecting standard output
# does not disturb the interface.
public isolated class UnixTerminal {
    *CursorReporter;

    private final string ttyPath;
    private boolean acquired = false;
    private string savedSettings = "";
    private boolean stopHandlerRegistered = false;
    private boolean readerStarted = false;
    private final ByteQueue queue = new;
    private int[] pending = [];
    private InputEvent[] ready = [];
    private decimal lastByteAt = 0;
    private Size? lastSize = ();
    private decimal lastSizeCheck = 0;
    private boolean inBandResize = false;
    private boolean cursorRequested = false;
    private CursorPosition? cursorReply = ();
    private boolean cursorUnsupported = false;

    # + ttyPath - the terminal device; the controlling terminal by default
    public isolated function init(string ttyPath = "/dev/tty") {
        self.ttyPath = ttyPath;
    }

    # Saves the terminal settings and switches to raw mode.
    #
    # + return - an error when the terminal is already acquired or is not available
    public isolated function acquire() returns error? {
        boolean startReader = false;
        lock {
            if self.acquired {
                return error("terminal already acquired");
            }
            if !isTerminalPath(self.ttyPath) {
                return error(string `not a terminal device: ${self.ttyPath}`);
            }
            string tty = shellQuote(self.ttyPath);
            // One shell for all of it (each process spawn costs about 15 ms): save the settings, switch to
            // raw mode, and read the size. The first line is the saved settings, the second "rows columns".
            string output = check shellWithin(string `saved=$(stty -g < ${tty}) && stty raw -echo min 1 time 0 < ${tty} ` +
                string `&& echo "$saved" && stty size < ${tty}`, 5);
            string[] lines = re `\n`.split(output.trim());
            if lines.length() != 2 {
                return error(string `unexpected output while taking over the terminal: ${output}`);
            }
            string saved = lines[0].trim();
            Size initialSize = check parseSize(lines[1]);
            self.savedSettings = saved;
            self.acquired = true;
            self.queue.clear();
            self.pending = [];
            self.ready = [];
            check io:fileWriteString(self.ttyPath, BRACKETED_PASTE_ON + RESIZE_REPORTS_ON, io:APPEND);
            self.inBandResize = false;
            self.cursorRequested = false;
            self.cursorReply = ();
            self.cursorUnsupported = false;
            self.lastSize = initialSize;
            self.lastSizeCheck = time:monotonicNow();
            if !self.readerStarted {
                self.readerStarted = true;
                startReader = true;
            }
            if !self.stopHandlerRegistered {
                self.stopHandlerRegistered = true;
                runtime:onGracefulStop(isolated function() returns error? {
                    return self.release();
                });
            }
        }
        if startReader {
            // One reader strand serves the terminal for its whole life: a blocked read cannot be
            // cancelled, so release does not stop it (it may take the next byte typed after release).
            _ = start readLoop(self.ttyPath, self.queue);
        }
    }

    # Restores the saved settings. Safe to call more than once.
    #
    # + return - an error when the settings cannot be restored
    public isolated function release() returns error? {
        lock {
            if !self.acquired {
                return;
            }
            self.acquired = false;
            self.cursorRequested = false;
            // One timed command: switch the reports off, then restore the saved settings. If the terminal
            // has gone away it is killed after a few seconds instead of blocking the process forever.
            string tty = shellQuote(self.ttyPath);
            _ = check shellWithin(string `printf '\033[?2004l\033[?2048l' > ${tty}; stty ${self.savedSettings} < ${tty}`, 3);
        }
    }

    # The size of the terminal.
    #
    # + return - the size, or an error when it cannot be read
    public isolated function size() returns Size|error {
        string output = (check shellWithin(string `stty size < ${shellQuote(self.ttyPath)}`, 2)).trim();
        return parseSize(output);
    }

    # Waits for the next input event, decoding the bytes the reader strand received. A lone Esc byte is
    # reported as the Escape key once nothing has followed it for a short time. Resizes arrive as
    # `ResizeEvent`s, from the terminal's own notifications where it sends them and from polling the
    # size about once a second otherwise.
    #
    # + return - the event, `()` when the terminal input has ended, or an error when reading fails
    public isolated function nextEvent() returns InputEvent|error? {
        while true {
            boolean checkSize = false;
            lock {
                if self.ready.length() > 0 {
                    InputEvent event = self.ready.remove(0);
                    return event.clone();
                }
                int[] fresh = self.queue.takeAll();
                if fresh.length() > 0 {
                    self.pending.push(...fresh);
                    self.lastByteAt = time:monotonicNow();
                    self.accept(decodeInput(self.pending, false, self.cursorRequested).cloneReadOnly());
                    continue;
                }
                if self.pending.length() > 0 && time:monotonicNow() - self.lastByteAt >= ESCAPE_TIMEOUT {
                    self.accept(decodeInput(self.pending, true, self.cursorRequested).cloneReadOnly());
                    self.lastByteAt = time:monotonicNow();
                    continue;
                }
                if self.pending.length() == 0 && self.queue.hasEnded() {
                    return self.queue.lastFailure();
                }
                if !self.inBandResize && time:monotonicNow() - self.lastSizeCheck >= RESIZE_POLL_INTERVAL {
                    self.lastSizeCheck = time:monotonicNow();
                    checkSize = true;
                }
            }
            if checkSize {
                // measured outside the lock: the size query takes about 15 ms and must not hold up writes
                Size|error current = self.size();
                if current is Size {
                    self.noteSize(current.cloneReadOnly());
                }
            }
            runtime:sleep(0.002);
        }
    }

    // Stores decoded events and what is left over, and learns from in-band resize notifications.
    private isolated function accept(DecodeResult & readonly decoded) {
        lock {
            self.pending = [...decoded.rest];
            CursorPosition? report = decoded.report;
            if report is CursorPosition {
                self.cursorReply = report.clone();
                self.cursorRequested = false;
            }
            foreach InputEvent event in decoded.events {
                if event is ResizeEvent {
                    self.inBandResize = true;
                    self.lastSize = {width: event.width, height: event.height};
                }
                self.ready.push(event.clone());
            }
        }
    }

    // Queues a resize event when the polled size differs from the last known one.
    private isolated function noteSize(Size & readonly current) {
        lock {
            Size? known = self.lastSize;
            if known is () || known != current {
                self.lastSize = current.clone();
                self.ready.push({kind: "resize", width: current.width, height: current.height});
            }
        }
    }

    # Asks the terminal where its cursor is (`ESC [ 6 n`) and waits for the reply, which `nextEvent`
    # picks out of the input, so `nextEvent` must be running on another strand (the runtime's input
    # loop does this). A terminal that does not answer within a fifth of a second is remembered as not
    # supporting it, so later calls return at once. Input that arrives meanwhile is kept.
    #
    # + return - the position, `()` when the terminal does not answer or is not acquired, or an error
    #            when the request cannot be written
    public isolated function queryCursor() returns CursorPosition|error? {
        lock {
            if !self.acquired || self.cursorUnsupported {
                return ();
            }
            self.cursorReply = ();
            self.cursorRequested = true;
        }
        error? sent = self.write(CURSOR_POSITION_REQUEST);
        decimal waited = 0;
        while sent is () && waited < CURSOR_REPORT_TIMEOUT {
            lock {
                CursorPosition? reply = self.cursorReply;
                if reply is CursorPosition {
                    self.cursorReply = ();
                    return reply.clone();
                }
            }
            runtime:sleep(0.002);
            waited += 0.002d;
        }
        lock {
            self.cursorRequested = false;
            if sent is () {
                self.cursorUnsupported = true;
            }
        }
        return sent;
    }

    # Writes the data to the terminal device in one call.
    #
    # + data - the output
    # + return - an error when the terminal cannot be written
    public isolated function write(string data) returns error? {
        if !isTerminalPath(self.ttyPath) {
            return error(string `not a terminal device: ${self.ttyPath}`);
        }
        return io:fileWriteString(self.ttyPath, data, io:APPEND);
    }
}
