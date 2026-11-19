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

@test:Config {}
function testByteQueueKeepsTheBytesThatWerePushed() {
    ByteQueue queue = new;
    byte[] chunk = [97, 98, 255, 0];
    queue.push(chunk.cloneReadOnly());
    queue.push((<byte[]>[1]).cloneReadOnly());
    test:assertEquals(queue.takeAll(), [97, 98, 255, 0, 1]);
    test:assertEquals(queue.takeAll(), [], "taking empties the queue");
}

@test:Config {}
function testByteQueueReportsHowInputEnded() {
    ByteQueue queue = new;
    test:assertFalse(queue.hasEnded());
    queue.finish(());
    test:assertTrue(queue.hasEnded());
    test:assertEquals(queue.lastFailure(), ());
    ByteQueue failed = new;
    failed.finish(error("read failed"));
    test:assertTrue(failed.hasEnded());
    test:assertTrue(failed.lastFailure() is error);
}

@test:Config {}
function testByteQueueCanBeCleared() {
    ByteQueue queue = new;
    queue.push((<byte[]>[1, 2, 3]).cloneReadOnly());
    queue.clear();
    test:assertEquals(queue.takeAll(), []);
}

@test:Config {}
function testTakingFromAnEmptyByteQueueGivesNothingAndKeepsTheQueueWorking() {
    ByteQueue queue = new;
    test:assertEquals(queue.takeAll(), <int[]>[]);
    test:assertEquals(queue.takeAll(), <int[]>[], "again");
    queue.push([97, 98]);
    test:assertEquals(queue.takeAll(), [97, 98]);
    test:assertEquals(queue.takeAll(), <int[]>[], "emptied by the take");
}
