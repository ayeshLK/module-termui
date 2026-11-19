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

import ayesha/termui;
import ayesha/termui.input;
import ayesha/termui.term;
import ayesha/termui.text;
import ballerina/lang.runtime;

const string MODEL = "dummy-agent-1";
const string[] SPINNER = ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"];

type Tick record {|
    "tick" kind = "tick";
|};

final text:Style DIM = {dim: true};
final text:Style BOLD = {bold: true};
final text:Style ACCENT = {fg: "brightCyan", bold: true};
final text:Style GREEN = {fg: "green"};
final text:Style RED = {fg: "red"};
final text:Style CODE = {fg: "yellow"};

const int NO_WRAP = 10000;

function sp(string t, text:Style style = {}) returns text:Span {
    return {text: t, style};
}

class Agent {
    *termui:Program;

    // the prompt: cursor, editing keys, multi-line input, paste and history
    private input:LineEditor editor = new;

    // turn state
    private boolean busy = false;
    private int turn = 0;
    private int frame = 0;
    private int ticks = 0;           // 1 tick = 0.1s
    private int turnStartTick = 0;
    private int tokens = 0;
    private int totalTokens = 0;
    private string statusText = "";
    private string partial = "";     // the line being streamed
    private boolean inCode = false;
    private CancelFlag? cancel = ();
    private boolean quitWhenIdle = false;
    private boolean leaving = false;   // once set, the last frame leaves nothing behind

    public function update(termui:Message message) returns termui:Command? {
        if message is Tick {
            self.frame = (self.frame + 1) % SPINNER.length();
            self.ticks += 1;
            return;
        }
        if message is term:KeyEvent {
            return self.onKey(message);
        }
        if message is term:PasteEvent {
            input:EditResult _ = self.editor.handleEvent(message);
            return;
        }
        if message is termui:InputEnded {
            if self.busy {
                self.quitWhenIdle = true;
                return;
            }
            return termui:quit();
        }
        if message is Status && message.turn == self.turn {
            self.statusText = message.text;
            return;
        }
        if message is Token && message.turn == self.turn {
            return self.onToken(message.text);
        }
        if message is ToolStarted && message.turn == self.turn {
            self.statusText = string `Running ${message.name}(${message.arg})`;
            return;
        }
        if message is ToolFinished && message.turn == self.turn {
            text:Span mark = message.ok ? sp("●", GREEN) : sp("●", RED);
            return termui:commitBlock([
                [mark, sp(" " + message.name, BOLD), sp("(" + message.arg + ")", DIM)],
                [sp("  ⎿  " + message.summary, DIM)]
            ]);
        }
        if message is TurnDone && message.turn == self.turn {
            termui:Command[] cmds = [self.flushPartial()];
            if message.interrupted {
                cmds.push(termui:commitProse([[sp("⏹ Interrupted by user", {fg: "yellow"})]]));
            }
            cmds.push(termui:commitProse([[]]));
            self.busy = false;
            self.cancel = ();
            self.totalTokens += self.tokens;
            self.tokens = 0;
            if self.quitWhenIdle {
                cmds.push(termui:quit());
            }
            return termui:batch(cmds);
        }
        if message is termui:EffectFailed {
            self.busy = false;
            return termui:commitProse([[sp("error: " + message.reason, RED)]]);
        }
        return;
    }

    public function view() returns text:Span[][] {
        text:Span[][] lines = [];
        if self.leaving {
            return lines;
        }
        if self.busy {
            if self.partial != "" {
                lines.push(self.styledLine(self.partial, self.inCode));
            }
            string secs = ((self.ticks - self.turnStartTick) / 10).toString();
            lines.push([
                sp(SPINNER[self.frame] + " ", ACCENT),
                sp(self.statusText + "… ", {fg: "cyan"}),
                sp(string `(${secs}s · ↓ ${self.tokens} tokens · esc to interrupt)`, DIM)
            ]);
        }
        // a width no line reaches, so the terminal wraps long input itself
        text:Span[][] prompt = self.editor.render(NO_WRAP, "❯ ");
        prompt[0][0] = sp("❯ ", ACCENT);
        lines.push(...prompt);
        lines.push([sp(string `  ${MODEL} · ${self.totalTokens + self.tokens} tokens · /help for commands · ctrl+d to quit`, DIM)]);
        return lines;
    }

    private function onKey(term:KeyEvent key) returns termui:Command? {
        if key.ctrl && (key.key == "c" || key.key == "d") {
            CancelFlag? c = self.cancel;
            if c is CancelFlag {
                c.cancel();
            }
            self.leaving = true;
            return termui:batch([termui:commitProse([[sp("Goodbye! 👋", DIM)]]), termui:quit()]);
        }
        if key.key == "escape" {
            CancelFlag? c = self.cancel;
            if self.busy && c is CancelFlag {
                c.cancel();
                self.statusText = "Interrupting";
            }
            return;
        }
        if self.busy && key.key == "enter" {
            return; // keep what is typed until the answer is finished
        }
        input:EditResult result = self.editor.handleEvent(key);
        if result is input:Submitted {
            return self.submit(result.text);
        }
        return;
    }

    private function submit(string typed) returns termui:Command? {
        string prompt = typed.trim();
        if prompt == "" {
            return;
        }

        text:Span[][] echo = [[sp("❯ ", ACCENT), sp(prompt, BOLD)]];
        if prompt == "/exit" || prompt == "/quit" {
            self.leaving = true;
            return termui:batch([termui:commitProse(echo), termui:quit()]);
        }
        if prompt == "/help" {
            return termui:batch([termui:commitProse(echo), termui:commitBlock([
                [sp("Commands", BOLD)],
                [sp("  /help   show this help")],
                [sp("  /exit   quit (also ctrl+d)")],
                [sp("Try asking", BOLD)],
                [sp("  fix the bug in the handler   → tool calls + approval prompts")],
                [sp("  explain how streaming works → streamed prose")],
                [sp("  write a test                 → short answer with code")],
                [sp("Keys: ↑/↓ history · alt+enter new line · esc interrupts a running answer", DIM)]
            ])]);
        }

        self.turn += 1;
        self.busy = true;
        self.tokens = 0;
        self.partial = "";
        self.inCode = false;
        self.turnStartTick = self.ticks;
        self.statusText = "Thinking";
        CancelFlag flag = new;
        self.cancel = flag;
        int turn = self.turn;
        Step[] plan = planFor(prompt);
        return termui:batch([termui:commitProse(echo), termui:effect(streamTurn(turn, plan.cloneReadOnly(), flag))]);
    }

    // Folds a streamed chunk into the current line; every completed line is committed to the scrollback.
    private function onToken(string chunk) returns termui:Command? {
        self.tokens += 1;
        termui:Command[] cmds = [];
        foreach string:Char c in chunk {
            if c == "\n" {
                termui:Command? done = self.finishLine();
                if done is termui:Command {
                    cmds.push(done);
                }
            } else {
                self.partial += c;
            }
        }
        self.statusText = "Responding";
        return cmds.length() == 0 ? () : termui:batch(cmds);
    }

    private function finishLine() returns termui:Command? {
        string line = self.partial;
        self.partial = "";
        if line.startsWith("```") {
            self.inCode = !self.inCode;
            return;   // hide the fences, the code block is shown indented and colored
        }
        if self.inCode {
            return termui:commitBlock([self.styledLine(line, true)]);
        }
        // commitBlock wraps at word boundaries; commitProse would leave the wrapping to the terminal, which
        // can split a word at the right edge.
        return termui:commitBlock([self.styledLine(line, false)]);
    }

    private function flushPartial() returns termui:Command {
        if self.partial == "" {
            return termui:batch([]);
        }
        return self.finishLine() ?: termui:batch([]);
    }

    private function styledLine(string line, boolean code) returns text:Span[] {
        if code {
            return [sp("    " + line, CODE)];
        }
        // render `inline code` in a different color
        text:Span[] spans = [];
        string current = "";
        boolean inline = false;
        foreach string:Char c in line {
            if c == "`" {
                if current != "" {
                    spans.push(sp(current, inline ? CODE : {}));
                }
                current = "";
                inline = !inline;
            } else {
                current += c;
            }
        }
        if current != "" {
            spans.push(sp(current, inline ? CODE : {}));
        }
        return spans.length() == 0 ? [sp("")] : spans;
    }
}

// The fake LLM call: runs on its own strand and reports back only with messages.
function streamTurn(int turn, readonly & Step[] plan, CancelFlag flag) returns termui:EffectFunction {
    return isolated function(termui:Session session) returns error? {
        boolean interrupted = false;
        foreach Step step in plan {
            if flag.isCancelled() {
                interrupted = true;
                break;
            }
            if step.kind == "think" {
                session.send({kind: "status", turn, text: step.text});
                runtime:sleep(1.2);
            } else if step.kind == "text" {
                session.send({kind: "status", turn, text: "Responding"});
                foreach string piece in chunks(step.text) {
                    if flag.isCancelled() {
                        interrupted = true;
                        break;
                    }
                    session.send({kind: "token", turn, text: piece});
                    runtime:sleep(0.045);
                }
            } else {
                session.send({kind: "toolStarted", turn, name: step.text, arg: step.arg});
                boolean allowed = true;
                if step.approval {
                    allowed = check session.confirm(string `Allow ${step.text}(${step.arg})?`, false);
                }
                if allowed {
                    runtime:sleep(1.0);
                }
                session.send({
                    kind: "toolFinished", turn, name: step.text, arg: step.arg,
                    summary: allowed ? step.result : "denied by user", ok: allowed
                });
            }
            if interrupted {
                break;
            }
        }
        session.send({kind: "turnDone", turn, interrupted});
    };
}

public function main() returns error? {
    termui:Interface ui = new (term:detectEnvironment());
    termui:Command banner = termui:batch([
        termui:commitBlock([
            [sp("╭" + rep("─", 41) + "╮", ACCENT)],
            boxLine(" ✻ Welcome to Dummy Agent", BOLD),
            boxLine("   a Ballerina + termui demo", DIM),
            [sp("╰" + rep("─", 41) + "╯", ACCENT)]
        ]),
        termui:every(0.1, {kind: "tick"})
    ]);
    check ui.run(new Agent(), banner, anchorBottom = true);
}

function boxLine(string content, text:Style style) returns text:Span[] {
    string pad = rep(" ", 41 - content.length());
    return [sp("│", ACCENT), sp(content, style), sp(pad + "│", ACCENT)];
}

function rep(string s, int n) returns string {
    string out = "";
    foreach int _ in 0 ..< n {
        out += s;
    }
    return out;
}
