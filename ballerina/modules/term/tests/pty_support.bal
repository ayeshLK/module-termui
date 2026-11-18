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
import ballerina/lang.runtime;
import ballerina/os;

// Support for the tty tests: a Python helper owns a pseudo-terminal pair, the test opens the slave
// device through UnixTerminal, and the two coordinate through marker files in a temporary directory.

const string PTY_HELPER = "tests/resources/pty_helper.py";

function newWorkDir() returns string|error {
    os:Process process = check os:exec({value: "mktemp", arguments: ["-d"]});
    byte[] output = check process.output();
    _ = check process.waitForExit();
    return (check string:fromBytes(output)).trim();
}

function touch(string dir, string name) returns error? {
    check io:fileWriteString(dir + "/" + name, "x");
}

function waitFor(string dir, string name, decimal timeout = 30) returns error? {
    decimal waited = 0;
    while waited < timeout {
        string|io:Error content = io:fileReadString(dir + "/" + name);
        if content is string {
            return;
        }
        runtime:sleep(0.02d);
        waited += 0.02d;
    }
    return error("timed out waiting for " + name);
}

function startHelper(string dir, json plan) returns os:Process|error {
    check io:fileWriteString(dir + "/plan.json", plan.toJsonString());
    return os:exec({value: "python3", arguments: [PTY_HELPER, dir, dir + "/plan.json"]});
}

// Waits for the helper to finish and returns what it recorded.
function finishHelper(os:Process helper, string dir) returns map<json>|error {
    _ = check helper.waitForExit();
    string text = check io:fileReadString(dir + "/result.json");
    json result = check text.fromJsonString();
    return check result.cloneWithType();
}

// The slave device the helper created, ready to be opened by a UnixTerminal.
function helperTty(string dir) returns string|error {
    check waitFor(dir, "tty");
    return io:fileReadString(dir + "/tty");
}

function snapshotFlag(map<json> result, string label, string flag) returns boolean|error {
    map<json> snapshots = check result["snapshots"].cloneWithType();
    map<json> snapshot = check snapshots[label].cloneWithType();
    return check snapshot[flag].cloneWithType();
}

function snapshotAll(map<json> result, string label) returns json|error {
    map<json> snapshots = check result["snapshots"].cloneWithType();
    map<json> snapshot = check snapshots[label].cloneWithType();
    return snapshot["all"];
}

// What the application wrote, as seen from the master side.
function drained(map<json> result, string label) returns string|error {
    map<json> drains = check result["drains"].cloneWithType();
    string hex = check drains[label].cloneWithType();
    string out = "";
    int i = 0;
    while i + 1 < hex.length() {
        int code = check int:fromHexString(hex.substring(i, i + 2));
        out += check string:fromCodePointInt(code);
        i += 2;
    }
    return out;
}
