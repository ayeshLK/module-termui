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

# An in-memory terminal for tests and non-interactive use.
#
# Input is scripted with `pushEvent`, `pushText`, and `pushKey`; `nextEvent` returns the events in order
# and then `()`, without ever blocking. Output is applied to a small virtual screen (see `screenLines`)
# and every `write` is also logged whole (see `writes`), so tests can check both what the user would
# see and how it was written.
public isolated class FakeTerminal {
    *Terminal;

    private InputEvent[] script = [];
    private int nextIndex = 0;
    private boolean acquired = false;
    private string[] writeLog = [];
    private ScreenState screen;

    # + width - the number of columns
    # + height - the number of rows
    public isolated function init(int width = 80, int height = 24) {
        self.screen = newScreen(width, height);
    }

    # Takes the terminal over. Fails if it is already acquired.
    #
    # + return - an error when the terminal is already acquired
    public isolated function acquire() returns error? {
        lock {
            if self.acquired {
                return error("terminal already acquired");
            }
            self.acquired = true;
        }
    }

    # Gives the terminal back. Safe to call more than once.
    #
    # + return - always `()`
    public isolated function release() returns error? {
        lock {
            self.acquired = false;
        }
    }

    # The current size.
    #
    # + return - the size
    public isolated function size() returns Size|error {
        lock {
            return {width: self.screen.width, height: self.screen.height};
        }
    }

    # The next scripted event, or `()` when the script has run out.
    #
    # + return - the event, or `()`
    public isolated function nextEvent() returns InputEvent|error? {
        lock {
            if self.nextIndex < self.script.length() {
                InputEvent event = self.script[self.nextIndex];
                self.nextIndex += 1;
                return event.clone();
            }
        }
        return ();
    }

    # Records the write and applies it to the virtual screen.
    #
    # + data - the output
    # + return - always `()`
    public isolated function write(string data) returns error? {
        lock {
            self.writeLog.push(data);
            applyOutput(self.screen, data);
        }
    }

    # Adds an event to the end of the input script.
    #
    # + event - the event
    public isolated function pushEvent(InputEvent event) {
        lock {
            self.script.push(event.clone());
        }
    }

    # Adds one key event for each character of the text.
    #
    # + text - the characters typed
    public isolated function pushText(string text) {
        foreach string:Char char in text {
            self.pushEvent({kind: "key", key: char});
        }
    }

    # Adds a key event for a named key.
    #
    # + key - the key
    # + ctrl - whether Ctrl is held
    # + alt - whether Alt is held
    # + shift - whether Shift is held
    public isolated function pushKey(NamedKey key, boolean ctrl = false, boolean alt = false, boolean shift = false) {
        self.pushEvent({kind: "key", key, ctrl, alt, shift});
    }

    # Resizes the screen and adds a resize event to the input script.
    #
    # + width - the new number of columns
    # + height - the new number of rows
    # + reflow - whether the terminal re-wraps text that was wrapped automatically when the width
    #            changes (most modern terminals do); with `false` the text is cut off instead
    public isolated function resize(int width, int height, boolean reflow = true) {
        lock {
            resizeScreen(self.screen, width, height, reflow);
            self.script.push({kind: "resize", width, height});
        }
    }

    # Every write so far, each as it was passed to `write`.
    #
    # + return - the writes, oldest first
    public isolated function writes() returns string[] {
        lock {
            return self.writeLog.clone();
        }
    }

    # The rows of the visible screen, with trailing spaces trimmed.
    #
    # + return - one string per row
    public isolated function screenLines() returns string[] {
        lock {
            string[] lines = [];
            foreach string[] cells in self.screen.cells {
                lines.push(rowText(cells));
            }
            return lines.clone();
        }
    }

    # The visible screen as text: rows joined by newlines, without trailing empty rows.
    #
    # + return - the screen text
    public isolated function screenText() returns string {
        string[] lines = self.screenLines();
        int end = lines.length();
        while end > 0 && lines[end - 1] == "" {
            end -= 1;
        }
        return string:'join("\n", ...lines.slice(0, end));
    }

    # The lines that scrolled off the top of the screen, oldest first.
    #
    # + return - the scrollback
    public isolated function scrollbackLines() returns string[] {
        lock {
            return self.screen.scrollback.clone();
        }
    }

    # The cursor position, counted from zero.
    #
    # + return - the row and the column
    public isolated function cursorPosition() returns [int, int] {
        lock {
            return [self.screen.row, self.screen.col];
        }
    }

    # Whether the terminal is currently acquired.
    #
    # + return - `true` between `acquire` and `release`
    public isolated function isAcquired() returns boolean {
        lock {
            return self.acquired;
        }
    }
}
