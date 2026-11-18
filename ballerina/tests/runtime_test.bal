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
import ballerina/lang.runtime;
import ballerina/test;

// ---- test program -------------------------------------------------------------------------------

function kindOf(Message message) returns string? {
    if message is map<anydata> {
        anydata kind = message["kind"];
        return kind is string ? kind : ();
    }
    return ();
}

function countKind(Message[] messages, string kind) returns int {
    int total = 0;
    foreach Message message in messages {
        if kindOf(message) == kind {
            total += 1;
        }
    }
    return total;
}

// One program with a key for each thing the tests need; q quits.
class TestProgram {
    *Program;

    Message[] seen = [];
    int count = 0;
    int views = 0;

    public function update(Message message) returns Command? {
        self.seen.push(message);
        if message is term:KeyEvent {
            string pressed = message.key;
            match pressed {
                "q" => {
                    return quit();
                }
                "+" => {
                    self.count += 1;
                }
                "e" => {
                    return effect(isolated function(Session session) returns error? {
                        runtime:sleep(0.3);
                        session.send({kind: "done"});
                    });
                }
                "s" => {
                    return effect(isolated function(Session session) returns error? {
                        foreach int n in 1 ... 3 {
                            session.send({kind: "part", n});
                            runtime:sleep(0.01);
                        }
                    });
                }
                "x" => {
                    return effect(isolated function(Session session) returns error? {
                        return error("boom");
                    });
                }
                "t" => {
                    return every(0.02, {kind: "tick"});
                }
                "c" => {
                    return commitProse([[{text: "committed line"}]]);
                }
                "p" => {
                    return effect(isolated function(Session session) returns error? {
                        boolean|error answer = session.confirm("Delete?");
                        session.send({kind: "answer", value: answer is boolean ? (answer ? 1 : 0) : -1});
                    });
                }
                "d" => {
                    return effect(isolated function(Session session) returns error? {
                        boolean|error answer = session.confirm("Keep?", true);
                        session.send({kind: "answer", value: answer is boolean ? (answer ? 1 : 0) : -1});
                    });
                }
                "o" => {
                    return effect(isolated function(Session session) returns error? {
                        int|error answer = session.choose("Pick one", ["one", "two", "three"]);
                        session.send({kind: "answer", value: answer is int ? answer : -1});
                    });
                }
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        self.views += 1;
        return [[{text: "count: " + self.count.toString()}]];
    }

    function answers() returns int[] {
        int[] values = [];
        foreach Message message in self.seen {
            if kindOf(message) == "answer" && message is map<anydata> {
                anydata value = message["value"];
                if value is int {
                    values.push(value);
                }
            }
        }
        return values;
    }
}

function keysSeen(TestProgram program) returns string {
    string keys = "";
    foreach Message message in program.seen {
        if message is term:KeyEvent {
            keys += message.key;
        }
    }
    return keys;
}

function keyMessage(string:Char|term:NamedKey key) returns Message {
    term:KeyEvent event = {kind: "key", key};
    return event.cloneReadOnly();
}

function newEngine(TestProgram program, term:FakeTerminal terminal) returns Engine {
    render:InlineRenderer renderer = new (terminal, 40, 10);
    return new Engine(program, terminal, renderer);
}

// Steps the engine until the condition holds.
function pump(Engine engine, function () returns boolean done, decimal seconds = 5) returns error? {
    decimal waited = 0;
    while !done() {
        boolean keepGoing = check engine.step();
        if !keepGoing {
            return;
        }
        runtime:sleep(0.005);
        waited += 0.005d;
        if waited > seconds {
            return error("timed out waiting");
        }
    }
}

// ---- 6.1 queue ----------------------------------------------------------------------------------

isolated function produce(Queue queue, int producer, int total) {
    foreach int seq in 0 ..< total {
        queue.push({producer, seq});
    }
}

@test:Config {}
function testQueueDeliversInOrderAndDropsNothingFromConcurrentProducers() {
    MessageQueue queue = new;
    foreach int producer in 0 ..< 4 {
        _ = start produce(queue, producer, 250);
    }
    Message[] received = [];
    int polls = 0;
    while received.length() < 1000 && polls < 2000 {
        received.push(...queue.takeAll());
        runtime:sleep(0.005);
        polls += 1;
    }
    test:assertEquals(received.length(), 1000, "no message may be dropped");
    int[] next = [0, 0, 0, 0];
    foreach Message message in received {
        map<anydata> fields = <map<anydata>>message;
        int producer = <int>fields["producer"];
        int seq = <int>fields["seq"];
        test:assertEquals(seq, next[producer], "messages of one producer must stay in keyOrder");
        next[producer] = seq + 1;
    }
}

@test:Config {}
function testTakingFromAnEmptyQueueNeverWaits() {
    MessageQueue queue = new;
    test:assertEquals(queue.takeAll(), []);
    queue.push({kind: "one"});
    test:assertEquals(queue.takeAll().length(), 1);
    test:assertEquals(queue.takeAll(), []);
}

// ---- 6.2 loop and frame coalescing ---------------------------------------------------------------

@test:Config {}
function testFiftyQueuedMessagesDrawExactlyOneFrame() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    foreach int _ in 0 ..< 50 {
        engine.session.send(keyMessage("+"));
    }
    boolean keepGoing = check engine.step();
    test:assertTrue(keepGoing);
    test:assertEquals(program.count, 50, "every message must be applied");
    test:assertEquals(program.views, 1, "but only one frame is drawn");
    test:assertEquals(terminal.writes().length(), 1);
    test:assertEquals(terminal.screenLines()[0], "count: 50");
}

@test:Config {}
function testMessagesAreAppliedInTheOrderTheyArrived() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    engine.session.send(keyMessage("a"));
    engine.session.send(keyMessage("b"));
    engine.session.send(keyMessage("c"));
    _ = check engine.step();
    string keyOrder = "";
    foreach Message message in program.seen {
        if message is term:KeyEvent {
            keyOrder += message.key;
        }
    }
    test:assertEquals(keyOrder, "abc");
}

@test:Config {}
function testAFrameIsDrawnOnlyWhenSomethingHappened() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    _ = check engine.step(); // the first frame
    _ = check engine.step();
    _ = check engine.step();
    test:assertEquals(program.views, 1);
    test:assertEquals(terminal.writes().length(), 1);
}

// ---- 6.3 effects -----------------------------------------------------------------------------------

@test:Config {}
function testAStreamingEffectDeliversEachResultAsAMessage() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    engine.session.send(keyMessage("s"));
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "part") == 3;
    });
    int[] parts = [];
    foreach Message message in program.seen {
        if kindOf(message) == "part" {
            parts.push(<int>(<map<anydata>>message)["n"]);
        }
    }
    test:assertEquals(parts, [1, 2, 3]);
}

@test:Config {}
function testEveryMessageIsImmutable() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    terminal.pushText("ab");
    Engine engine = newEngine(program, terminal);
    engine.launch();
    engine.session.send(keyMessage("s"));
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "part") == 3 && countKind(program.seen, "inputEnded") == 1;
    });
    foreach Message message in program.seen {
        test:assertTrue(message is readonly, "messages from every source must be readonly");
    }
}

@test:Config {}
function testAFailingEffectReportsAMessage() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    engine.session.send(keyMessage("x"));
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "effectFailed") == 1;
    });
    Message failure = program.seen[program.seen.length() - 1];
    test:assertEquals((<map<anydata>>failure)["reason"], "boom");
}

@test:Config {}
function testCommandsCanCommitOutputAboveTheRegion() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("c"));
    _ = check engine.step();
    test:assertEquals(terminal.screenLines().slice(0, 3), ["committed line", "count: 0", ""]);
}

// ---- 6.4 sources ----------------------------------------------------------------------------------

@test:Config {}
function testKeysAreDeliveredWhileALongEffectRuns() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    engine.session.send(keyMessage("e")); // an effect that takes 0.3 s
    engine.session.send(keyMessage("a"));
    engine.session.send(keyMessage("b"));
    engine.session.send(keyMessage("c"));
    check pump(engine, function() returns boolean {
        return program.seen.length() >= 4;
    });
    test:assertEquals(countKind(program.seen, "done"), 0, "the keys arrive before the effect has finished");
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "done") == 1;
    });
}

@test:Config {}
function testTerminalInputBecomesMessages() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    terminal.pushText("+");
    terminal.pushKey("up", ctrl = true);
    terminal.pushEvent({text: "pasted"});
    Engine engine = newEngine(program, terminal);
    engine.launch();
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "inputEnded") == 1;
    });
    test:assertEquals(program.count, 1);
    test:assertTrue(program.seen[1] is term:KeyEvent);
    test:assertEquals(program.seen[2], <term:PasteEvent>{text: "pasted"});
}

@test:Config {}
function testAResizeReachesTheRendererAndTheProgram() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    _ = check engine.step();
    terminal.resize(30, 8);
    engine.launch();
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "inputEnded") == 1;
    });
    boolean sawResize = false;
    foreach Message message in program.seen {
        if message is term:ResizeEvent {
            sawResize = message.width == 30 && message.height == 8;
        }
    }
    test:assertTrue(sawResize, "the program must be told about the new size");
    test:assertEquals(terminal.screenLines()[0], "count: 0", "and the region is drawn again at the new size");
}

@test:Config {}
function testTicksArriveRepeatedly() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    engine.session.send(keyMessage("t"));
    check pump(engine, function() returns boolean {
        return countKind(program.seen, "tick") >= 3;
    });
    engine.stop();
}

// ---- 6.5 shutdown ---------------------------------------------------------------------------------

@test:Config {}
function testQuittingRestoresTheTerminalAndEndsTheRun() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    terminal.pushText("+++q");
    check run(program, terminal);
    test:assertFalse(terminal.isAcquired(), "the terminal must be released");
    test:assertEquals(program.count, 3);
    test:assertEquals(terminal.screenLines()[0], "count: 3");
}

@test:Config {}
function testNoMessageIsDeliveredAfterTheProgramHasStopped() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    _ = check engine.step();
    int before = program.seen.length();
    engine.stop();
    engine.session.send(keyMessage("+"));
    _ = check engine.step();
    test:assertEquals(program.seen.length(), before, "a stopped program receives nothing");
    test:assertTrue(engine.session.isStopped());
}

@test:Config {}
function testMessagesAfterAQuitAreDropped() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    engine.session.send(keyMessage("q"));
    engine.session.send(keyMessage("+"));
    boolean keepGoing = check engine.step();
    test:assertFalse(keepGoing);
    test:assertEquals(program.count, 0);
}

@test:Config {}
function testTheTerminalIsReleasedEvenWhenDrawingFails() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    // a screen that cannot be drawn on makes the first frame fail
    BrokenTerminal broken = new (terminal);
    error? outcome = run(program, broken);
    test:assertTrue(outcome is error);
    test:assertFalse(terminal.isAcquired());
}

isolated class BrokenTerminal {
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
        return error("the screen is gone");
    }
}

// ---- 6.6 prompts ----------------------------------------------------------------------------------

function showsPrompt(term:FakeTerminal terminal, string question) returns boolean {
    return terminal.screenText().includes(question);
}

@test:Config {}
function testConfirmReturnsTheAnswerAndClearsThePrompt() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("p"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Delete?");
    });
    test:assertTrue(terminal.screenText().includes("? Delete? (y/n)"));
    engine.session.send(keyMessage("y"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [1]);
    _ = check engine.step();
    test:assertFalse(showsPrompt(terminal, "Delete?"), "the prompt must be cleared from the live region");
    test:assertFalse(keysSeen(program).includes("y"), "the answering key must not reach the program");
}

@test:Config {}
function testKeysAnswerThePromptInsteadOfReachingTheProgram() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("p"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Delete?");
    });
    engine.session.send(keyMessage("+")); // not an answer: ignored by the prompt, and not given to the program
    engine.session.send(keyMessage("n"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [0]);
    test:assertEquals(program.count, 0, "keys typed during a question belong to the question");
}

@test:Config {}
function testEnterUsesTheDefaultAnswer() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("d"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Keep?");
    });
    test:assertTrue(terminal.screenText().includes("(Y/n)"));
    engine.session.send(keyMessage("enter"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [1]);
}

@test:Config {}
function testEscapeAnswersNo() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("p"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Delete?");
    });
    engine.session.send(keyMessage("escape"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [0]);
}

@test:Config {}
function testChooseReturnsTheSelectedIndex() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("o"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Pick one");
    });
    test:assertEquals(terminal.screenLines().slice(1, 5), ["? Pick one", "> one", "  two", "  three"]);
    engine.session.send(keyMessage("down"));
    engine.session.send(keyMessage("down"));
    engine.session.send(keyMessage("up"));
    _ = check engine.step();
    test:assertEquals(terminal.screenLines().slice(2, 5), ["  one", "> two", "  three"]);
    engine.session.send(keyMessage("enter"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [1]);
    _ = check engine.step();
    test:assertFalse(showsPrompt(terminal, "Pick one"));
}

@test:Config {}
function testEscapeCancelsAChoice() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("o"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Pick one");
    });
    engine.session.send(keyMessage("escape"));
    check pump(engine, function() returns boolean {
        return program.answers().length() == 1;
    });
    test:assertEquals(program.answers(), [-1]);
}

@test:Config {}
function testAQuestionEndsWithAnErrorWhenTheProgramStops() returns error? {
    TestProgram program = new;
    term:FakeTerminal terminal = new (40, 10);
    Engine engine = newEngine(program, terminal);
    engine.session.send(keyMessage("p"));
    check pump(engine, function() returns boolean {
        return showsPrompt(terminal, "Delete?");
    });
    engine.stop();
    // the waiting effect gives up and its error becomes an answer of -1, which nobody receives any more;
    // what matters is that the effect strand does not wait forever
    runtime:sleep(0.1);
    test:assertTrue(engine.session.isStopped());
}

// ---- 6.7 the example in Module.md -----------------------------------------------------------------

// Mirrors the example in Module.md; if this changes, update the documentation to match.
class DocCounter {
    *Program;

    int count = 0;

    public function update(Message message) returns Command? {
        if message is term:KeyEvent {
            if message.key == "+" {
                self.count += 1;
            } else if message.key == "q" {
                return quit();
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "count: " + self.count.toString()}]];
    }
}

@test:Config {}
function testModuleDocExample() returns error? {
    term:FakeTerminal terminal = new (30, 4);
    terminal.pushText("++q");
    check run(new DocCounter(), terminal);
    test:assertEquals(terminal.screenText(), "count: 2");
}

// ---- output keeps the order of the messages ------------------------------------------------------

class OrderingProgram {
    *Program;

    private final term:FakeTerminal terminal;

    function init(term:FakeTerminal terminal) {
        self.terminal = terminal;
    }

    public function update(Message message) returns Command? {
        if message is term:KeyEvent {
            if message.key == "c" {
                return commitProse([[{text: "committed"}]]);
            }
            if message.key == "r" {
                // output the program writes itself, as a result on standard output would be
                error? written = self.terminal.write("RESULT\r\n");
                if written is error {
                    return quit();
                }
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [];
    }
}

@test:Config {}
function testCommittedOutputAndOwnOutputKeepTheOrderOfTheMessages() returns error? {
    term:FakeTerminal terminal = new (40, 10);
    OrderingProgram program = new (terminal);
    render:InlineRenderer renderer = new (terminal, 40, 10);
    Engine engine = new (program, terminal, renderer);
    // all in one batch: whatever the batching, "committed" came first and so it must be written first
    engine.session.send(keyMessage("c"));
    engine.session.send(keyMessage("r"));
    engine.session.send(keyMessage("c"));
    _ = check engine.step();
    test:assertEquals(terminal.screenLines().slice(0, 3), ["committed", "RESULT", "committed"]);
}
