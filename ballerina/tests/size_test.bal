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
import ballerina/test;

// The size the program is drawn with is its first message (see "The terminal size is the first message").

function sizes(TestProgram program) returns [int, int][] {
    [int, int][] found = [];
    foreach Message message in program.seen {
        if message is term:ResizeEvent {
            found.push([message.width, message.height]);
        }
    }
    return found;
}

@test:Config {}
function testTheFirstMessageIsTheTerminalSizeBeforeAnyKey() returns error? {
    term:FakeTerminal terminal = new (100, 30);
    terminal.pushText("+q"); // already waiting when the program starts
    TestProgram program = new;
    check run(program, terminal);
    test:assertEquals(program.seen.length() >= 3, true);
    Message first = program.seen[0];
    test:assertTrue(first is term:ResizeEvent, "the first message is a resize event");
    test:assertEquals(sizes(program), [[100, 30]]);
    test:assertTrue(program.seen[1] is term:KeyEvent, "the keys come after it");
    test:assertEquals(program.count, 1);
}

@test:Config {}
function testALaterResizeIsStillDeliveredAfterTheInitialSize() returns error? {
    term:FakeTerminal terminal = new (100, 30);
    terminal.resize(60, 20); // already waiting in the input when the program starts
    TestProgram program = new;
    Engine engine = newEngine(program, terminal);
    engine.launch((), {width: 100, height: 30});
    check pump(engine, function () returns boolean {
        return sizes(program).length() == 2;
    });
    engine.stop();
    test:assertEquals(sizes(program), [[100, 30], [60, 20]], "the size told first, then the change");
}

@test:Config {}
function testAnUnsizedTerminalDeliversTheFallbackSize() returns error? {
    term:FakeTerminal screen = new (80, 24);
    screen.pushText("q");
    TestProgram program = new;
    check run(program, new Unsized(screen));
    test:assertEquals(sizes(program), [[80, 24]], "the default fallback, which is also what the renderer draws with");

    term:FakeTerminal other = new (80, 24);
    other.pushText("q");
    TestProgram sized = new;
    check run(sized, new Unsized(other), {fallbackSize: {width: 40, height: 10}});
    test:assertEquals(sizes(sized), [[40, 10]], "the fallback from the options");
}

@test:Config {}
function testTheInterfaceTellsTheProgramTheSizeItDrawsWith() returns error? {
    term:FakeTerminal screen = new (80, 24);
    screen.pushText("q");
    Interface ui = new (term:environmentFrom({COLUMNS: "40", LINES: "10"}, false, false, false), terminal = new Unsized(screen));
    TestProgram program = new;
    check ui.run(program);
    test:assertEquals(sizes(program), [[40, 10]], "no terminal: the environment's size");
}

@test:Config {}
function testDeliveringTheSizeWritesNothingToTheTerminal() returns error? {
    term:FakeTerminal told = new (40, 10);
    term:FakeTerminal untold = new (40, 10);
    TestProgram withSize = new;
    TestProgram without = new;
    Engine first = newEngine(withSize, told);
    Engine second = newEngine(without, untold);
    first.launch((), {width: 40, height: 10});
    second.launch();
    _ = check first.step();
    _ = check second.step();
    first.stop();
    second.stop();
    test:assertEquals(sizes(withSize), [[40, 10]]);
    test:assertEquals(sizes(without), []);
    test:assertEquals(told.writes(), untold.writes(), "the size is not a resize: the terminal sees the same bytes");
    test:assertEquals(told.screenLines(), untold.screenLines());
}
