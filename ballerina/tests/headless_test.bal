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
import ballerina/io;
import ballerina/os;
import ballerina/test;
import ballerina/time;

// io:fileReadString drops a trailing newline, so read the bytes to see exactly what was written.
function readFile(string path) returns string|error {
    return string:fromBytes(check io:fileReadBytes(path));
}

function env(boolean stdinTty, boolean stdoutTty, map<string> variables = {}) returns term:Environment {
    return term:environmentFrom(variables, stdinTty, stdoutTty, stdoutTty);
}

// ---- 7.1 mode selection ------------------------------------------------------------------------------

@test:Config {}
function testFullyInteractiveUsesTheTerminalAndTheInlineRenderer() {
    Interface ui = new (env(true, true));
    test:assertEquals(ui.mode, "interactive");
    test:assertTrue(ui.interactive);
    test:assertTrue(ui.terminal is term:UnixTerminal);
    test:assertTrue(ui.renderer() is render:InlineRenderer);
    test:assertTrue(ui.options().interactive);
}

@test:Config {}
function testFullyHeadlessUsesPlainOutput() {
    Interface ui = new (env(false, false));
    test:assertEquals(ui.mode, "headless");
    test:assertFalse(ui.interactive);
    test:assertTrue(ui.terminal is term:StreamTerminal);
    test:assertTrue(ui.renderer() is render:PlainRenderer);
    test:assertFalse(ui.options().interactive);
    test:assertFalse(ui.options().colors);
}

@test:Config {}
function testRedirectedInputMeansNobodyCanAnswer() {
    Interface ui = new (env(false, true));
    test:assertEquals(ui.mode, "pipedInput");
    test:assertFalse(ui.interactive);
    test:assertTrue(ui.renderer() is render:PlainRenderer);
}

@test:Config {}
function testRedirectedOutputKeepsTheInterfaceOnTheTerminal() {
    Interface ui = new (env(true, false));
    test:assertEquals(ui.mode, "pipedOutput");
    test:assertTrue(ui.interactive, "a terminal is still there to answer questions");
    test:assertTrue(ui.terminal is term:UnixTerminal);
    test:assertTrue(ui.renderer() is render:InlineRenderer);
    test:assertTrue(ui.options().colors, "the interface is drawn on the terminal, so color is fine");
}

@test:Config {}
function testNoColorStillAppliesOnTheTerminal() {
    test:assertFalse(new Interface(env(true, true, {NO_COLOR: "1"})).options().colors);
    test:assertFalse(new Interface(env(true, false, {TERM: "dumb"})).options().colors);
}

// ---- 7.2 data on stdout, interface on the terminal --------------------------------------------------------

class ReportProgram {
    *Program;

    private final Interface ui;
    private final string dir;
    private boolean announced = false;

    function init(Interface ui, string dir) {
        self.ui = ui;
        self.dir = dir;
    }

    public function update(Message message) returns Command? {
        if message is term:KeyEvent {
            if message.key == "r" {
                error? written = self.ui.result("answer: 42");
                if written is error {
                    return quit();
                }
            } else if message.key == "q" {
                return quit();
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        if !self.announced {
            self.announced = true;
            error? marker = touch(self.dir, "go"); // the interface is up: let the helper type
            if marker is error {
                return [[{text: "marker failed"}]];
            }
        }
        return [[{text: "working", style: {bold: true, fg: "green"}}]];
    }
}

@test:Config {groups: ["tty"]}
function testOnlyResultsGoToRedirectedOutput() returns error? {
    string dir = check newWorkDir();
    os:Process helper = check startHelper(dir, [
        {op: "wait", file: "go"},
        {op: "send", hex: "72"},
        {op: "send", hex: "71"},
        {op: "drain", label: "out", until_file: "done"},
        {op: "wait", file: "finished"}
    ]);
    string tty = check helperTty(dir);
    string resultFile = dir + "/stdout.txt";
    Interface ui = new (env(true, false), tty, resultFile);
    check ui.run(new ReportProgram(ui, dir));
    check touch(dir, "done");
    check touch(dir, "finished");
    map<json> result = check finishHelper(helper, dir);

    string stdout = check readFile(resultFile);
    test:assertEquals(stdout, "answer: 42\n", "the redirected output must contain the result and nothing else");
    string onTerminal = check drained(result, "out");
    test:assertTrue(onTerminal.includes("working"), "the interface is drawn on the terminal");
    test:assertTrue(onTerminal.includes("\u{1b}["), "with its cursor control");
    test:assertFalse(onTerminal.includes("answer: 42"), "results do not go to the terminal");
}

// ---- 7.3 prompts without a terminal -----------------------------------------------------------------------

@test:Config {}
function testQuestionsWithoutATerminalReturnImmediately() {
    Session session = new (new MessageQueue(), new PromptBoard(), false);
    decimal started = time:monotonicNow();
    boolean|error noDefault = session.confirm("Delete everything?");
    test:assertTrue(noDefault is NoTerminal, "no default and no terminal is an error");
    test:assertEquals(session.confirm("Delete everything?", false), false);
    test:assertEquals(session.confirm("Continue?", true), true);
    int|error noChoice = session.choose("Pick", ["a", "b"]);
    test:assertTrue(noChoice is NoTerminal);
    test:assertEquals(session.choose("Pick", ["a", "b"], 1), 1);
    test:assertTrue(session.choose("Pick", ["a", "b"], 5) is NoTerminal, "a default that is not an option is no default");
    test:assertTrue(time:monotonicNow() - started < 1d, "nothing may wait for input");
}

@test:Config {}
function testTheErrorNamesTheQuestion() {
    Session session = new (new MessageQueue(), new PromptBoard(), false);
    boolean|error answer = session.confirm("Delete everything?");
    if answer is error {
        test:assertTrue(answer.message().includes("Delete everything?"));
    } else {
        test:assertFail("there is no terminal, so there must be an error");
    }
}

@test:Config {}
function testAProgramAskingWithoutATerminalGetsTheErrorAsAnAnswer() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    render:InlineRenderer renderer = new (terminal, 40, 10);
    Engine engine = new (program, terminal, renderer, false);
    engine.session.send(keyMessage("p"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [-1]);
    test:assertFalse(terminal.screenText().includes("Delete?"), "no question may be shown");
}

// ---- 7.4 deterministic plain output ---------------------------------------------------------------------

class ReportingProgram {
    *Program;

    public function update(Message message) returns Command? {
        if message is InputEnded {
            return batch([
                commitProse([[{text: "first paragraph", style: {bold: true, fg: "red"}}]]),
                commitBlock([[{text: "| a very wide table row that is certainly longer than eighty columns once it has been written out in full |"}]]),
                quit()
            ]);
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "spinner |"}]];
    }
}

function runHeadless(string file) returns error? {
    Interface ui = new (env(false, false), "/dev/tty", file);
    check ui.run(new ReportingProgram());
}

@test:Config {}
function testHeadlessOutputIsPlainAndRepeatable() returns error? {
    string dir = check newWorkDir();
    check runHeadless(dir + "/one.txt");
    check runHeadless(dir + "/two.txt");
    string first = check readFile(dir + "/one.txt");
    string second = check readFile(dir + "/two.txt");
    test:assertEquals(first, second, "two runs must produce identical bytes");
    test:assertFalse(first.includes("\u{1b}"), "no escape sequences");
    test:assertFalse(first.includes("\r"), "no carriage returns");
    test:assertTrue(first.startsWith("first paragraph\n"));
    test:assertTrue(first.endsWith("spinner |\n"), "the live region is written once, as its final state");
}

@test:Config {}
function testTextIsWrappedAtEightyColumnsWhenTheWidthIsUnknown() returns error? {
    string dir = check newWorkDir();
    check runHeadless(dir + "/wide.txt");
    string output = check readFile(dir + "/wide.txt");
    foreach string line in re `\n`.split(output) {
        test:assertTrue(text:displayWidth(line) <= 80, "line wider than 80 columns: " + line);
    }
    test:assertTrue(re `\n`.split(output).length() > 3, "the long row must have been wrapped");
}

// ---- 7.5 the example in Package.md ---------------------------------------------------------------------

// Mirrors the example in Package.md; if this changes, update the documentation to match.
class DocReport {
    *Program;

    public function update(Message message) returns Command? {
        if message is InputEnded {
            return batch([
                commitProse([[{text: "report ready"}]]),
                quit()
            ]);
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "working..."}]];
    }
}

@test:Config {}
function testPackageDocExample() returns error? {
    string dir = check newWorkDir();
    Interface ui = new (env(false, false), "/dev/tty", dir + "/out.txt");
    check ui.run(new DocReport());
    test:assertEquals(check readFile(dir + "/out.txt"), "report ready\nworking...\n");
}

// ---- a result written while the interface is on the terminal ---------------------------------------------------------

class ResultProgram {
    *Program;

    private final Interface ui;
    private int lines = 0;

    function init(Interface ui) {
        self.ui = ui;
    }

    public function update(Message message) returns Command? {
        if message is term:KeyEvent {
            if message.key == "r" {
                self.lines += 1;
                error? written = self.ui.result("result " + self.lines.toString());
                if written is error {
                    return quit();
                }
            } else if message.key == "q" {
                return quit();
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "live line"}], [{text: "| status"}]];
    }
}

// When standard output is the terminal, a result written straight to it would land in the middle of the
// live region and throw the renderer's row accounting off by one; it must be committed above the region.
@test:Config {}
function testAResultOnTheTerminalDoesNotCorruptTheLiveRegion() returns error? {
    term:FakeTerminal terminal = new (40, 10);
    term:Environment environment = term:environmentFrom({COLUMNS: "40", LINES: "10"}, true, true, true);
    Interface ui = new (environment, terminal = terminal);
    terminal.pushText("rrrq");
    check ui.run(new ResultProgram(ui));
    test:assertEquals(terminal.screenLines().slice(0, 6), ["result 1", "result 2", "result 3", "live line", "| status", ""]);
}
