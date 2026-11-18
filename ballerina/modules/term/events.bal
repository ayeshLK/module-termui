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

# A key that is not a printable character.
public type NamedKey "enter"|"tab"|"backspace"|"delete"|"escape"|"up"|"down"|"left"|"right"|"home"|"end"|
    "pageUp"|"pageDown"|"insert"|"f1"|"f2"|"f3"|"f4"|"f5"|"f6"|"f7"|"f8"|"f9"|"f10"|"f11"|"f12";

# A key press.
#
# + kind - always `key`; tells the event types apart
# + key - the printable character (a single code point), or the named key
# + ctrl - whether Ctrl was held
# + alt - whether Alt (Option) was held
# + shift - whether Shift was held, for keys where that is reported
public type KeyEvent record {|
    "key" kind = "key";
    string:Char|NamedKey key;
    boolean ctrl = false;
    boolean alt = false;
    boolean shift = false;
|};

# Text pasted into the terminal (bracketed paste), delivered as one event.
#
# + kind - always `paste`
# + text - the pasted text, possibly with several lines
public type PasteEvent record {|
    "paste" kind = "paste";
    string text;
|};

# The terminal was resized.
#
# + kind - always `resize`
# + width - the new width in columns
# + height - the new height in rows
public type ResizeEvent record {|
    "resize" kind = "resize";
    int width;
    int height;
|};

# Anything the user or the terminal can send to the application.
public type InputEvent KeyEvent|PasteEvent|ResizeEvent;

# The size of a terminal.
#
# + width - the number of columns
# + height - the number of rows
public type Size record {|
    int width;
    int height;
|};
