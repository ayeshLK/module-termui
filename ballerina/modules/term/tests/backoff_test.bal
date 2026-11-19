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

import ballerina/test;

// Runs the schedule for `seconds` of idleness and returns the interval in force at the end and the
// seconds at which each new interval was first slept.
function simulate(decimal base, decimal ceiling, decimal seconds) returns [decimal, [decimal, decimal][]] {
    decimal interval = base;
    int empty = 0;
    decimal elapsed = 0;
    [decimal, decimal][] reached = [];
    while elapsed < seconds {
        elapsed += interval;
        decimal before = interval;
        [interval, empty] = backOff(interval, empty, base, ceiling);
        if interval != before {
            reached.push([interval, elapsed]);
        }
    }
    return [interval, reached];
}

@test:Config {}
function testTheIntervalDoublesAfterEveryTwentyEmptyChecksUpToTheCeiling() {
    [decimal, [decimal, decimal][]] [_, reached] = simulate(0.005, 0.5, 30);
    decimal[] intervals = [];
    decimal[] times = [];
    foreach [decimal, decimal] [interval, at] in reached {
        intervals.push(interval);
        times.push(at);
    }
    decimal[] expectedIntervals = [0.010, 0.020, 0.040, 0.080, 0.160, 0.320, 0.5];
    // the idle time at which each interval starts, as in the design's table (about 0.1, 0.3, 0.7, 1.5, 3.1, 6.3, 12.7 s)
    decimal[] expectedTimes = [0.100, 0.300, 0.700, 1.500, 3.100, 6.300, 12.700];
    test:assertEquals(intervals, expectedIntervals);
    test:assertEquals(times, expectedTimes);
}

@test:Config {}
function testTheIntervalStaysAtTheCeiling() {
    [decimal, [decimal, decimal][]] [last, _] = simulate(0.005, 0.5, 120);
    test:assertEquals(last, 0.5d);
}

@test:Config {}
function testACeilingBetweenTwoStepsIsNotExceeded() {
    [decimal, [decimal, decimal][]] [last, reached] = simulate(0.005, 0.03, 10);
    test:assertEquals(last, 0.03d);
    test:assertEquals(reached.length(), 3, "10 ms, 20 ms and then the ceiling");
}

@test:Config {}
function testACeilingAtOrBelowTheBaseTurnsTheBackoffOff() {
    [decimal, [decimal, decimal][]] [equalLast, equalReached] = simulate(0.005, 0.005, 60);
    test:assertEquals(equalLast, 0.005d);
    test:assertEquals(equalReached.length(), 0);
    [decimal, [decimal, decimal][]] [belowLast, belowReached] = simulate(0.005, 0.001, 60);
    test:assertEquals(belowLast, 0.005d);
    test:assertEquals(belowReached.length(), 0);
}

@test:Config {}
function testTheInputLoopsBaseWorksTheSameWay() {
    [decimal, [decimal, decimal][]] [last, reached] = simulate(0.002, 0.5, 60);
    test:assertEquals(last, 0.5d);
    test:assertEquals(reached[0][0], 0.004d);
    test:assertEquals(reached[0][1], 0.04d, "20 checks of 2 ms");
}

@test:Config {}
function testActivityRestartsTheScheduleFromTheBase() {
    decimal interval = 0.005;
    int empty = 0;
    foreach int _ in 0 ..< 45 {
        [interval, empty] = backOff(interval, empty, 0.005, 0.5);
    }
    test:assertTrue(interval > 0.005d, "backed off");
    // the caller resets on activity: interval = base, empty = 0, and the schedule starts again
    interval = 0.005;
    empty = 0;
    [interval, empty] = backOff(interval, empty, 0.005, 0.5);
    test:assertEquals(interval, 0.005d);
    test:assertEquals(empty, 1);
}
