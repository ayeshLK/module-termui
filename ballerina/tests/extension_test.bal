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

import ayesha/termui.render;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/test;

// The contract of `Renderer` and `Terminal` is the set of methods the types declare, and nothing more:
// an implementation written outside the package, with none of the optional abilities, has to keep
// working. These tests are that implementation. If a required method is ever added to either type,
// they stop compiling.

// A renderer that only does what `render:Renderer` requires, and writes what it is asked to into a log.
isolated class MinimalRenderer {
    *render:Renderer;

    private string[] log = [];

    public isolated function draw(text:Span[][] lines) returns error? {
        lock {
            self.log.push("draw:" + lines.length().toString());
        }
    }

    public isolated function commitProse(text:Span[][] paragraphs) returns error? {
        lock {
            self.log.push("prose:" + paragraphs.length().toString());
        }
    }

    public isolated function commitBlock(text:Span[][] lines) returns error? {
        lock {
            self.log.push("block:" + lines.length().toString());
        }
    }

    public isolated function resize(int width, int height) returns error? {
        lock {
            self.log.push(string `resize:${width}x${height}`);
        }
    }

    public isolated function close() returns error? {
        lock {
            self.log.push("close");
        }
    }

    isolated function entries() returns string[] {
        lock {
            return self.log.clone();
        }
    }
}

// A terminal that only does what `term:Terminal` requires: no cursor report, nothing optional.
isolated class MinimalTerminal {
    *term:Terminal;

    private final term:FakeTerminal inner;

    isolated function init(term:FakeTerminal inner) {
        self.inner = inner;
    }

    public isolated function acquire() returns error? {
        return self.inner.acquire();
    }

    public isolated function release() returns error? {
        return self.inner.release();
    }

    public isolated function size() returns term:Size|error {
        return self.inner.size();
    }

    public isolated function nextEvent() returns term:InputEvent|error? {
        return self.inner.nextEvent();
    }

    public isolated function write(string data) returns error? {
        return self.inner.write(data);
    }
}

@test:Config {}
function testAProgramRunsOnAMinimalRenderer() returns error? {
    term:FakeTerminal fake = new (30, 8);
    fake.pushText("c+q");
    MinimalRenderer renderer = new;
    TestProgram program = new;
    check run(program, new MinimalTerminal(fake), renderer = renderer);
    string[] entries = renderer.entries();
    test:assertTrue(entries.indexOf("prose:1") is int, "commits reach the renderer's own method");
    test:assertTrue(entries.indexOf("draw:1") is int, "frames reach the renderer's own method");
    test:assertEquals(entries[entries.length() - 1], "close", "the renderer is closed at the end");
    test:assertEquals(program.count, 1);
}

@test:Config {}
function testAProgramRunsOnAMinimalTerminal() returns error? {
    term:FakeTerminal fake = new (30, 8);
    fake.pushText("++q");
    TestProgram program = new;
    check run(program, new MinimalTerminal(fake));
    test:assertEquals(program.count, 2);
    test:assertTrue(fake.screenText().includes("count: 2"), "the program is drawn through the required methods only");
}

@test:Config {}
function testBottomAnchoringWithoutACursorReportFallsBackQuietly() returns error? {
    term:FakeTerminal fake = new (30, 8);
    fake.pushText("+q");
    TestProgram program = new;
    check run(program, new MinimalTerminal(fake), {anchorBottom: true});
    test:assertTrue(fake.screenText().includes("count: 1"), "a terminal without the optional ability still works");
}

@test:Config {}
function testTheRunSettingsKeepTheirDefaults() {
    Options options = {};
    test:assertEquals(options.colors, true);
    test:assertEquals(options.reflow, true);
    test:assertEquals(options.anchorBottom, false);
    test:assertEquals(options.interactive, true);
    test:assertEquals(options.pollInterval, 0.005d);
    test:assertEquals(options.maxPollInterval, 0.5d);
    test:assertEquals(options.initialCommand, ());
}
