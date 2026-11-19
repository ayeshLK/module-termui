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

import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/lang.runtime;
import ballerina/test;
import ballerina/time;

// While nothing happens the loop lengthens its sleep (see "An idle loop checks less often"). These tests use
// small ceilings so they stay short, and margins that tolerate a busy machine.

// Sends messages from an effect after an idle pause and records how long each waited for the loop.
class LateProgram {
    *Program;

    decimal pause;
    decimal[] gaps;
    int[] arrived = [];
    decimal[] waited = [];

    function init(decimal pause, decimal[] gaps) {
        self.pause = pause;
        self.gaps = gaps;
    }

    public function update(Message message) returns Command? {
        if message is term:KeyEvent && message.key == "g" {
            final decimal pause = self.pause;
            final decimal[] & readonly gaps = self.gaps.cloneReadOnly();
            return effect(isolated function(Session session) returns error? {
                runtime:sleep(pause);
                foreach int n in 0 ..< gaps.length() {
                    runtime:sleep(gaps[n]);
                    session.send({kind: "late", n, sentAt: time:monotonicNow()});
                }
            });
        }
        if message is map<anydata> && message["kind"] == "late" {
            anydata n = message["n"];
            anydata sentAt = message["sentAt"];
            if n is int && sentAt is decimal {
                self.arrived.push(n);
                self.waited.push(<decimal>time:monotonicNow() - sentAt);
                if self.arrived.length() == self.gaps.length() {
                    return quit();
                }
            }
        }
        return ();
    }

    public function view() returns text:Span[][] {
        return [[{text: "idle"}]];
    }
}

@test:Config {}
function testMessagesAfterAnIdlePauseAreDeliveredInOrderWithinTheCeiling() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    terminal.pushText("g");
    // a pause long enough for the sleep to reach the 40 ms ceiling, then two messages 0.2 s apart
    LateProgram program = new (1.5, [0.0, 0.2]);
    check run(program, terminal, {pollInterval: 0.005, maxPollInterval: 0.04});
    test:assertEquals(program.arrived, [0, 1], "every message is delivered, in order");
    // the ceiling is 40 ms: a generous margin for a slow machine, far below what a 0.5 s sleep would give
    test:assertTrue(program.waited[0] <= 0.3d, string `the first message waited ${program.waited[0].toString()} s for the loop`);
    test:assertTrue(program.waited[1] <= 0.3d, string `the second message waited ${program.waited[1].toString()} s for the loop`);
}

// The loop's sleeps, driven without sleeping: steps that find nothing lengthen the sleep, anything else restores it.
@test:Config {}
function testTheSleepGrowsWhileIdleAndReturnsToTheBaseOnActivity() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    TestProgram program = new;
    Engine engine = newEngine(program, terminal);
    engine.launch();
    // let the first frame and the end of the (empty) input go by: those are activity
    check pump(engine, function () returns boolean {
        return countKind(program.seen, "inputEnded") >= 1;
    });
    decimal sleep = engine.nextSleep(0.005, 0.5);
    test:assertEquals(sleep, 0.005d, "a step that had something to do sleeps the base");
    // idle steps: the sleep doubles after every 20 of them
    foreach int _ in 0 ..< 19 {
        _ = check engine.step();
        sleep = engine.nextSleep(0.005, 0.5);
    }
    test:assertEquals(sleep, 0.005d, "19 empty checks");
    _ = check engine.step();
    test:assertEquals(engine.nextSleep(0.005, 0.5), 0.010d, "the 20th empty check doubles it");
    foreach int _ in 0 ..< 400 {
        _ = check engine.step();
        sleep = engine.nextSleep(0.005, 0.5);
    }
    test:assertEquals(sleep, 0.5d, "and it stops at the ceiling");
    // a message that is not a tick ends the backoff
    engine.session.send({kind: "other"});
    _ = check engine.step();
    test:assertEquals(engine.nextSleep(0.005, 0.5), 0.005d, "back to the base after activity");
    engine.stop();
}

@test:Config {}
function testTheSleepNeverGrowsWhenTheCeilingIsAtTheBase() returns error? {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 5));
    engine.launch();
    check pump(engine, function () returns boolean {
        return countKind(program.seen, "inputEnded") >= 1;
    });
    decimal sleep = 0;
    foreach int _ in 0 ..< 100 {
        _ = check engine.step();
        sleep = engine.nextSleep(0.005, 0.005);
    }
    engine.stop();
    test:assertEquals(sleep, 0.005d);
}

@test:Config {}
function testACeilingAtTheBaseKeepsTheShortSleepWhenIdle() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    terminal.pushText("g");
    LateProgram program = new (1.5, [0.0]);
    check run(program, terminal, {pollInterval: 0.005, maxPollInterval: 0.005});
    test:assertEquals(program.arrived, [0]);
    test:assertTrue(program.waited[0] <= 0.05d, string `with the backoff off the message waited ${program.waited[0].toString()} s`);
}

@test:Config {}
function testATimerTickIsNotActivityAndTheCeilingFollowsTheTimer() returns error? {
    term:FakeTerminal terminal = new (40, 10);
    terminal.pushText("t"); // TestProgram starts an `every` timer of 0.02 s
    TestProgram program = new;
    Engine engine = newEngine(program, terminal);
    engine.launch();
    _ = check engine.step();
    check pump(engine, function () returns boolean {
        return countKind(program.seen, "tick") >= 1;
    });
    test:assertEquals(engine.ceiling(0.5, 0.005), 0.01d, "half the timer's period");
    // later ticks are handled without ending the backoff
    check pump(engine, function () returns boolean {
        return countKind(program.seen, "tick") >= 3;
    });
    boolean tickOnly = !engine.wasActive();
    engine.stop();
    test:assertTrue(tickOnly, "a step that handled only ticks is not activity");
}

@test:Config {}
function testWithoutATimerTheCeilingIsTheOneAskedFor() {
    TestProgram program = new;
    Engine engine = newEngine(program, new term:FakeTerminal(40, 10));
    test:assertEquals(engine.ceiling(0.5, 0.005), 0.5d);
    test:assertEquals(engine.ceiling(0.04, 0.005), 0.04d);
}

@test:Config {}
function testTheInterfacePassesTheCeilingToTheRunOptions() {
    Interface byDefault = new (term:environmentFrom({}, false, false, false));
    test:assertEquals(byDefault.options().maxPollInterval, 0.5d);
    Interface lowered = new (term:environmentFrom({}, false, false, false), maxPollInterval = 0.05);
    test:assertEquals(lowered.options().maxPollInterval, 0.05d);
}

@test:Config {}
function testTakingFromAnEmptyMessageQueueGivesNothingAndKeepsTheQueueWorking() {
    MessageQueue queue = new;
    test:assertEquals(queue.takeAll(), <Message[]>[]);
    test:assertEquals(queue.takeAll(), <Message[]>[], "again");
    queue.push("a");
    queue.push("b");
    test:assertEquals(queue.takeAll(), <Message[]>["a", "b"]);
    test:assertEquals(queue.takeAll(), <Message[]>[], "emptied by the take");
}

// ---- a tick that changes nothing draws nothing ----------------------------------------------------------

// A program whose view shows how many ticks it has seen, or does not, as asked.
class TickCounter {
    *Program;

    boolean showTicks;
    int ticks = 0;
    int others = 0;
    int views = 0;

    function init(boolean showTicks) {
        self.showTicks = showTicks;
    }

    public function update(Message message) returns Command? {
        if message is term:KeyEvent && message.key == "t" {
            return every(0.02, {kind: "tick"});
        }
        if message is term:KeyEvent && message.key == "g" {
            return effect(isolated function(Session session) returns error? {
                runtime:sleep(0.1);
                session.send({kind: "other"});
            });
        }
        if message is map<anydata> && message["kind"] == "tick" {
            self.ticks += 1;
        }
        if message is map<anydata> && message["kind"] == "other" {
            self.others += 1;
        }
        return ();
    }

    public function view() returns text:Span[][] {
        self.views += 1;
        return [[{text: self.showTicks ? string `ticks: ${self.ticks}` : "waiting"}]];
    }
}

function drawCount(MinimalRenderer renderer) returns int {
    int count = 0;
    foreach string entry in renderer.entries() {
        if entry.startsWith("draw:") {
            count += 1;
        }
    }
    return count;
}

@test:Config {}
function testATickThatChangesNothingDrawsNothing() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    terminal.pushText("t");
    TickCounter program = new (false);
    MinimalRenderer renderer = new;
    Engine engine = new (program, terminal, renderer);
    engine.launch();
    _ = check engine.step();
    check pump(engine, function () returns boolean {
        return program.ticks >= 2;
    });
    int afterTwoTicks = drawCount(renderer);
    check pump(engine, function () returns boolean {
        return program.ticks >= 6;
    });
    engine.stop();
    test:assertEquals(drawCount(renderer), afterTwoTicks, "four more ticks, and no more draws");
    test:assertTrue(afterTwoTicks <= 2, "the first frame, and the one after the key that started the timer");
}

@test:Config {}
function testATickThatChangesTheViewIsDrawn() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    terminal.pushText("t");
    TickCounter program = new (true);
    MinimalRenderer renderer = new;
    Engine engine = new (program, terminal, renderer);
    engine.launch();
    _ = check engine.step();
    check pump(engine, function () returns boolean {
        return program.ticks >= 2;
    });
    int afterTwoTicks = drawCount(renderer);
    check pump(engine, function () returns boolean {
        return program.ticks >= 5;
    });
    engine.stop();
    test:assertTrue(drawCount(renderer) > afterTwoTicks, "ticks that change the view are drawn");
}

@test:Config {}
function testAMessageThatIsNotATickIsDrawnEvenWhenTheViewIsTheSame() returns error? {
    term:FakeTerminal terminal = new (40, 5);
    terminal.pushText("g"); // makes the program send itself an ordinary message 0.1 s later
    TickCounter program = new (false);
    MinimalRenderer renderer = new;
    Engine engine = new (program, terminal, renderer);
    engine.launch();
    check pump(engine, function () returns boolean {
        return program.others >= 1;
    });
    engine.stop();
    test:assertEquals(program.views >= 2, true);
    test:assertTrue(drawCount(renderer) >= 2, "the first frame, and a frame for the message, although the view did not change");
}
