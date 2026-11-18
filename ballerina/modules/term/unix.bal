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
const string BRACKETED_PASTE_OFF = "\u{1b}[?2004l";

// How long an Esc byte waits for the rest of a sequence before it is reported as the Escape key.
const decimal ESCAPE_TIMEOUT = 0.05;

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
    *Terminal;

    private final string ttyPath;
    private boolean acquired = false;
    private string savedSettings = "";
    private boolean stopHandlerRegistered = false;
    private boolean readerStarted = false;
    private final ByteQueue queue = new;
    private int[] pending = [];
    private InputEvent[] ready = [];
    private decimal lastByteAt = 0;

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
            string saved = (check shell(string `stty -g < ${tty}`)).trim();
            _ = check shell(string `stty raw -echo min 1 time 0 < ${tty}`);
            self.savedSettings = saved;
            self.acquired = true;
            self.queue.clear();
            self.pending = [];
            self.ready = [];
            check io:fileWriteString(self.ttyPath, BRACKETED_PASTE_ON, io:APPEND);
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
            io:Error? pasteOff = io:fileWriteString(self.ttyPath, BRACKETED_PASTE_OFF, io:APPEND);
            if pasteOff is io:Error {
                // best effort: restoring the settings below matters more than turning bracketed paste off
                self.acquired = false;
            }
            _ = check shell(string `stty ${self.savedSettings} < ${shellQuote(self.ttyPath)}`);
        }
    }

    # The size of the terminal.
    #
    # + return - the size, or an error when it cannot be read
    public isolated function size() returns Size|error {
        string output = (check shell(string `stty size < ${shellQuote(self.ttyPath)}`)).trim();
        string[] parts = re ` `.split(output);
        if parts.length() != 2 {
            return error(string `unexpected stty size output: ${output}`);
        }
        int rows = check int:fromString(parts[0]);
        int columns = check int:fromString(parts[1]);
        return {width: columns, height: rows};
    }

    # Waits for the next input event, decoding the bytes the reader strand received. A lone Esc byte is
    # reported as the Escape key once nothing has followed it for a short time.
    #
    # + return - the event, `()` when the terminal input has ended, or an error when reading fails
    public isolated function nextEvent() returns InputEvent|error? {
        while true {
            lock {
                if self.ready.length() > 0 {
                    InputEvent event = self.ready.remove(0);
                    return event.clone();
                }
                int[] fresh = self.queue.takeAll();
                if fresh.length() > 0 {
                    self.pending.push(...fresh);
                    self.lastByteAt = time:monotonicNow();
                    DecodeResult decoded = decodeInput(self.pending, false);
                    self.pending = decoded.rest;
                    self.ready.push(...decoded.events);
                    continue;
                }
                if self.pending.length() > 0 && time:monotonicNow() - self.lastByteAt >= ESCAPE_TIMEOUT {
                    DecodeResult decoded = decodeInput(self.pending, true);
                    self.pending = decoded.rest;
                    self.ready.push(...decoded.events);
                    self.lastByteAt = time:monotonicNow();
                    continue;
                }
                if self.pending.length() == 0 && self.queue.hasEnded() {
                    return self.queue.lastFailure();
                }
            }
            runtime:sleep(0.002);
        }
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
