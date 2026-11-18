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
import ballerina/io;

# There is no terminal to ask: the question was not answered because input is not interactive.
public type NoTerminal distinct error;

isolated function noTerminal(string question) returns NoTerminal {
    return error NoTerminal(string `cannot ask "${question}": there is no terminal to answer`);
}

# What a program talks to, chosen from how the process is attached: an interactive terminal, or plain
# output for scripts and pipes.
#
# - Interactive (and output redirected with a terminal still available): the interface is drawn on the
#   terminal; with redirected output, only results go to standard output.
# - Input redirected, or neither a terminal: plain text with no colors, cursor control, or animation,
#   written to standard output; questions return their defaults or a `NoTerminal` error at once.
public class Interface {
    # How the process is attached.
    public final term:Mode mode;
    # The terminal to hand to `run`.
    public final term:Terminal terminal;
    # Whether a user can answer questions.
    public final boolean interactive;

    private final term:Environment environment;
    private final string? resultFile;

    # + environment - what the process is attached to (see `term:detectEnvironment`)
    # + ttyPath - the terminal device to draw on in the interactive modes
    # + resultFile - write results to this file instead of standard output (for tests and for tools
    #                that capture them)
    public function init(term:Environment environment, string ttyPath = "/dev/tty", string? resultFile = ()) {
        self.environment = environment;
        self.mode = term:selectMode(environment);
        // with output redirected a terminal is still there, so questions can be asked
        self.interactive = self.mode == "interactive" || self.mode == "pipedOutput";
        self.resultFile = resultFile;
        if self.mode == "interactive" || self.mode == "pipedOutput" {
            self.terminal = new term:UnixTerminal(ttyPath);
        } else {
            self.terminal = new term:StreamTerminal(io:stdout, environment.width, environment.height, resultFile);
        }
    }

    // Colors are written when the interface is drawn on a terminal and neither NO_COLOR nor a dumb
    // terminal asks for none. Redirected standard output does not matter: the interface is not on it.
    private function colorsOnTerminal() returns boolean {
        boolean onTerminal = self.mode == "interactive" || self.mode == "pipedOutput";
        return onTerminal && !self.environment.noColor && !self.environment.dumbTerminal;
    }

    # A renderer that matches the mode: the inline interface on a terminal, plain text otherwise.
    #
    # + reflow - whether the terminal re-wraps text on resize (see `render:InlineRenderer`)
    # + return - the renderer
    public function renderer(boolean reflow = true) returns render:Renderer {
        if self.mode == "interactive" || self.mode == "pipedOutput" {
            return new render:InlineRenderer(self.terminal, self.environment.width, self.environment.height,
                self.colorsOnTerminal(), reflow);
        }
        return new render:PlainRenderer(self.terminal, self.environment.width);
    }

    # Options for `run` that match the mode.
    #
    # + return - the options
    public function options() returns Options {
        return {colors: self.colorsOnTerminal(), interactive: self.interactive};
    }

    # Writes a result: the output a caller or a pipe is waiting for. It always goes to standard output
    # (or the result file), never to the terminal the interface is drawn on, so a piped program gets
    # results and nothing else.
    #
    # + text - the result, written with a line feed
    # + return - an error when the output cannot be written
    public function result(string text) returns error? {
        string? file = self.resultFile;
        if file is string {
            return io:fileWriteString(file, text + "\n", io:APPEND);
        }
        io:println(text);
    }

    # Runs a program with the terminal, renderer, and options that match the mode.
    #
    # + program - the application
    # + return - an error when the terminal cannot be used or drawing fails
    public function run(Program program) returns error? {
        return run(program, self.terminal, self.options(), self.renderer());
    }
}
