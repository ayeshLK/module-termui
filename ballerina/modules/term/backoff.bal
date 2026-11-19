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

// How the loops that wait for work lengthen their sleep while nothing happens. A loop starts at its
// base interval and, after every EMPTY_CHECKS_PER_STEP checks that found nothing, doubles the interval up
// to a ceiling; the caller goes back to the base interval as soon as there is something to do. With a
// 5 ms base the schedule is 5, 10, 20, 40, 80, 160, 320 ms and then the ceiling, reached after about 13
// seconds of idleness, so a short pause costs little.
//
// This file is the same in the root module and in `term` (each module keeps its own private copy rather
// than making the function public API); the tests of both check the same schedule.

const int EMPTY_CHECKS_PER_STEP = 20;

// The interval to sleep after one more check that found nothing, and the count of empty checks so far at
// that interval. A ceiling at or below the base turns the backoff off.
isolated function backOff(decimal current, int emptyChecks, decimal base, decimal ceiling) returns [decimal, int] {
    if ceiling <= base {
        return [base, 0];
    }
    decimal now = current < base ? base : (current > ceiling ? ceiling : current);
    int counted = emptyChecks + 1;
    if counted < EMPTY_CHECKS_PER_STEP || now >= ceiling {
        return [now, now >= ceiling ? 0 : counted];
    }
    decimal doubled = now * 2;
    return [doubled > ceiling ? ceiling : doubled, 0];
}
