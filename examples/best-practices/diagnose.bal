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


// Used by the "Troubleshooting" page of the documentation site: one line that says how a program will run,
// to attach to a bug report.

import ayesha/termui.term;
import ballerina/io;

// region diagnose
// Describes how a program runs: the mode, which standard streams are terminals, whether color is on and
// the size assumed when the terminal cannot report one.
function describeEnvironment(term:Environment environment) returns string {
    term:Mode mode = term:selectMode(environment);
    return string `mode: ${mode}; stdin is a terminal: ${environment.stdinIsTerminal}; ` +
        string `stdout is a terminal: ${environment.stdoutIsTerminal}; ` +
        string `stderr is a terminal: ${environment.stderrIsTerminal}; color: ${environment.colorEnabled}; ` +
        string `fallback size: ${environment.width}x${environment.height}`;
}

// Call it once at startup, before the program runs.
function printEnvironment() {
    io:println(describeEnvironment(term:detectEnvironment()));
}
// endregion diagnose
