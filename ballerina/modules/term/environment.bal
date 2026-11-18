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

import ballerina/os;

# What the process is attached to and what the environment asks for.
#
# + stdinIsTerminal - whether standard input is an interactive terminal
# + stdoutIsTerminal - whether standard output is an interactive terminal
# + stderrIsTerminal - whether standard error is an interactive terminal
# + dumbTerminal - whether `TERM` is `dumb`, a terminal without cursor control
# + noColor - whether `NO_COLOR` asks for no color (set and not empty)
# + colorEnabled - whether color sequences may be written to standard output
# + width - the terminal width from `COLUMNS`, or 80 when it is unknown
# + height - the terminal height from `LINES`, or 24 when it is unknown
public type Environment record {|
    boolean stdinIsTerminal;
    boolean stdoutIsTerminal;
    boolean stderrIsTerminal;
    boolean dumbTerminal;
    boolean noColor;
    boolean colorEnabled;
    int width;
    int height;
|};

# The width assumed when no better value is known.
public const int DEFAULT_WIDTH = 80;

# The height assumed when no better value is known.
public const int DEFAULT_HEIGHT = 24;

// A child started with os:exec gets pipes for its own stdio, so it cannot ask whether the *parent's*
// stdio is a terminal. It can ask the operating system about its parent instead: /proc/<pid>/fd on
// Linux, lsof on macOS. Each line of output is "<fd> <target>", for example "1 /dev/ttys006".
const string STDIO_PROBE_SCRIPT = "pid=$PPID; for fd in 0 1 2; do " +
    "if [ -e /proc/$pid/fd/$fd ]; then target=$(readlink /proc/$pid/fd/$fd 2>/dev/null); " +
    "else target=$(lsof -n -P -a -p $pid -d $fd -Fn 2>/dev/null | sed -n 's/^n//p' | head -n 1); fi; " +
    "echo \"$fd $target\"; done";

# Whether a file path names an interactive terminal device.
#
# + path - the target of a standard file descriptor
# + return - `true` for tty, pty, and console devices
public isolated function isTerminalPath(string path) returns boolean {
    return path.startsWith("/dev/tty") || path.startsWith("/dev/pts/") || path == "/dev/console";
}

# Reads the output of the stdio probe.
#
# + output - lines of the form `<fd> <target>`
# + return - whether standard input, output, and error are terminals; a descriptor that is missing or
#            unknown counts as not a terminal
public isolated function parseStdioProbe(string output) returns [boolean, boolean, boolean] {
    boolean[] terminal = [false, false, false];
    foreach string line in re `\n`.split(output) {
        string trimmed = line.trim();
        int? space = trimmed.indexOf(" ");
        if space is int {
            int|error fd = int:fromString(trimmed.substring(0, space));
            if fd is int && fd >= 0 && fd <= 2 {
                terminal[fd] = isTerminalPath(trimmed.substring(space + 1).trim());
            }
        }
    }
    return [terminal[0], terminal[1], terminal[2]];
}

# Asks the operating system whether this process's standard streams are terminals.
#
# + return - whether standard input, output, and error are terminals, or an error when the probe cannot run
public isolated function probeStdio() returns [boolean, boolean, boolean]|error {
    os:Process process = check os:exec({value: "sh", arguments: ["-c", STDIO_PROBE_SCRIPT]});
    byte[] output = check process.output();
    _ = check process.waitForExit();
    return parseStdioProbe(check string:fromBytes(output));
}

isolated function positiveInt(string? value, int fallback) returns int {
    if value is string {
        int|error parsed = int:fromString(value.trim());
        if parsed is int && parsed > 0 {
            return parsed;
        }
    }
    return fallback;
}

# Works out the environment from environment variables and the terminal state of the standard streams.
#
# Color is enabled only when standard output is a terminal, `NO_COLOR` is unset or empty (the
# no-color.org convention), and `TERM` is not `dumb`.
#
# + variables - the environment variables
# + stdinIsTerminal - whether standard input is a terminal
# + stdoutIsTerminal - whether standard output is a terminal
# + stderrIsTerminal - whether standard error is a terminal
# + return - the environment
public isolated function environmentFrom(map<string> variables, boolean stdinIsTerminal, boolean stdoutIsTerminal,
        boolean stderrIsTerminal) returns Environment {
    boolean dumb = variables["TERM"] == "dumb";
    boolean noColor = (variables["NO_COLOR"] ?: "") != "";
    return {
        stdinIsTerminal,
        stdoutIsTerminal,
        stderrIsTerminal,
        dumbTerminal: dumb,
        noColor,
        colorEnabled: stdoutIsTerminal && !noColor && !dumb,
        width: positiveInt(variables["COLUMNS"], DEFAULT_WIDTH),
        height: positiveInt(variables["LINES"], DEFAULT_HEIGHT)
    };
}

# Detects the environment of the running process.
#
# Costs one short `sh` process (about 25 ms when it has to call `lsof`), so call it once at startup. If
# the probe fails, the standard streams are treated as not being terminals, which selects the safe
# non-interactive behavior.
#
# + return - the environment
public isolated function detectEnvironment() returns Environment {
    [boolean, boolean, boolean]|error probed = probeStdio();
    if probed is error {
        return environmentFrom(os:listEnv(), false, false, false);
    }
    return environmentFrom(os:listEnv(), probed[0], probed[1], probed[2]);
}

# How the program is attached to its surroundings.
#
# - `interactive`: input and output are both terminals.
# - `pipedOutput`: output is redirected but a terminal is available; the interface is drawn on the
#   terminal and only results go to standard output.
# - `pipedInput`: input is redirected, so nobody can answer questions.
# - `headless`: neither is a terminal (a script or a CI job).
public type Mode "interactive"|"pipedOutput"|"pipedInput"|"headless";

# Chooses the mode from what the process is attached to.
#
# + environment - the detected environment
# + return - the mode
public isolated function selectMode(Environment environment) returns Mode {
    if environment.stdinIsTerminal {
        return environment.stdoutIsTerminal ? "interactive" : "pipedOutput";
    }
    return environment.stdoutIsTerminal ? "pipedInput" : "headless";
}
