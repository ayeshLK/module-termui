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

import ballerina/io;

// Bytes read from the terminal by the reader strand, waiting to be decoded.
isolated class ByteQueue {
    private int[] bytes = [];
    private boolean ended = false;
    private error? failure = ();

    isolated function push(byte[] & readonly chunk) {
        lock {
            foreach int i in 0 ..< chunk.length() {
                // Convert explicitly: pushing a byte straight into an int array compiles, but fails at
                // runtime with a ClassCastException (bytes and ints have different representations).
                int value = chunk[i];
                self.bytes.push(value);
            }
        }
    }

    // Removes and returns everything queued so far; never waits.
    isolated function takeAll() returns int[] {
        lock {
            int[] all = self.bytes.clone();
            self.bytes = [];
            return all.clone();
        }
    }

    // Records that no more input will come, either normally (`()`) or because reading failed.
    isolated function finish(error? failure) {
        lock {
            self.ended = true;
            self.failure = failure;
        }
    }

    isolated function hasEnded() returns boolean {
        lock {
            return self.ended;
        }
    }

    isolated function lastFailure() returns error? {
        lock {
            return self.failure;
        }
    }

    isolated function clear() {
        lock {
            self.bytes = [];
        }
    }
}

// Reads the terminal device until it ends, pushing what arrives into the queue. A read blocks until
// at least one byte is available, so this runs on its own strand.
isolated function readLoop(string path, ByteQueue queue) {
    io:ReadableByteChannel|io:Error channel = io:openReadableFile(path);
    if channel is io:Error {
        queue.finish(channel);
        return;
    }
    while true {
        byte[]|io:Error chunk = channel.read(256);
        if chunk is io:Error {
            queue.finish(chunk is io:EofError ? () : chunk);
            return;
        }
        queue.push(chunk.cloneReadOnly());
    }
}
