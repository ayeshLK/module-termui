# Announcement drafts

Working drafts for announcing termui as a stable release. The links are filled in (repository, documentation site, tutorial). Re-check each channel's rules on self-promotion before posting.

## Where, in order

| # | Where | Why | Format |
|---|---|---|---|
| 1 | Ballerina Discord, Showcase channel | The community's live chat, with a channel for sharing what you build | Short post with the demo GIF and the docs link |
| 2 | Ballerina community Tech Blog | A permanent, searchable home (the official blog is for releases; ask in Discord how to submit) | The long post |
| 3 | `ballerina-lang` GitHub Discussions, General | Reaches people who follow the project | A short pointer, only if the rules allow self-posts |
| 4 | Your own blog, dev.to, or Hashnode | Reaches people searching for terminal UI and agent topics | The long post, cross-posted |
| 5 | Terminal and CLI communities | A different audience, interested in the design | A technical angle, not a library pitch |

One channel at a time over about a week, and answer every reply quickly.

## Before posting

- [x] 1.0.0 is on Ballerina Central, and the README install section uses it. (Publishing is permanent: a version cannot be overwritten or removed.)
- [x] The repository description and topics are set.
- [x] GitHub Discussions are enabled.
- [x] The documentation site is live, with the concepts, best practices and a six-step tutorial: https://ayeshlk.github.io/module-termui/
- [x] No `good first issue` labels, by decision: issues should come from the community.
- [ ] Each channel's rules on self-promotion have been read.

## Short post (Discord Showcase)

> **termui: build agent-style terminal apps in Ballerina**
> A small live region (spinner, status line, prompt) redrawn in place, finished output going into your normal scrollback, and an approval prompt like the ones agent CLIs use.
> What I care about most: the same program runs interactively, with its output piped, and in CI. In a pipe only the result goes to stdout, and questions return their default instead of hanging. It is also testable without a terminal, and effects are `isolated` so the compiler checks the concurrency.
> Stable, with semantic versioning (the policy is in the repo), macOS and Linux. It includes a text input with readline-style editing, multi-line and history.
> Docs, with a tutorial that builds a small agent harness step by step (prompt, streaming, interrupt, approval, tests): https://ayeshlk.github.io/module-termui/
> Demo and a 25-line quickstart in the repo: https://github.com/ayeshLK/module-termui
> I would love feedback on the API, and on what an agent CLI needs that is missing.

Attach `docs/assets/harness-demo.gif`.

## Long post (Tech Blog, dev.to)

**Title:** Building an agent-style CLI in Ballerina: a live region, an approval prompt, and output that behaves in a pipe

Agent CLIs have raised the bar for what a terminal program feels like: text streams in as it is produced, a spinner and status line stay put at the bottom, and before anything risky happens it stops and asks. I wanted that in Ballerina, so I built **termui**.

*(demo GIF)*

**The part people forget: the pipe.** Many of these programs are also run in scripts. If `agent > out.txt` fills the file with spinner frames, or a script hangs on a question nobody can answer, the tool is unusable in automation. termui decides what to do from what the process is attached to. With output redirected, the interface stays on your terminal and only the result goes to the file. With no terminal at all, you get plain text, no questions asked (the default is used), and the same bytes on every run.

**How it feels to write.** You write a program with two methods: `update(message)` and `view()`. Keys, timers and the results of long-running work all arrive as messages, and the runtime draws one frame per batch, writing only the cells that changed.

*(the 25-line counter from the README)*

Long-running work is an *effect*: an `isolated` function that can only talk back by sending immutable messages. A mutable message or a non-isolated effect does not compile, so the rule "never touch UI state from another strand" is checked for you.

**Testing without a terminal.** A `FakeTerminal` with a small virtual screen (including text reflow on resize) lets you script keystrokes and assert on what was drawn. Most of termui's own tests work this way, plus a set that runs against a real pseudo-terminal.

**What I learned building it.** A few things surprised me, and they are in the design notes: a child process cannot tell whether its parent's output is a terminal, so you have to ask the operating system; terminals disagree about whether they re-wrap text on resize; and recording the demo caught a real bug that no unit test had, because standard output *is* the live region when you run interactively.

**Where it stands.** It is stable: the API follows semantic versioning, and `COMPATIBILITY.md` in the repository says what that covers. It runs on macOS and Linux only, and takes about 0.3 s to the first frame on the JVM. A `LineEditor` (cursor movement, word editing, multi-line input, paste and history) is included. Missing: more widgets (a select list, a spinner), incremental markdown, and a bridge to Ballerina's AI module.

**Where to start.** The documentation site (https://ayeshlk.github.io/module-termui/) explains how the pieces work and what to avoid, and its tutorial builds a small harness in six steps: a prompt, a streamed answer, a status line with Esc to interrupt, a tool call that asks for approval, and tests. Every program in it is built and tested in CI, and the tutorial uses a scripted model, so it needs no account or key; it says where a real model would plug in.

Code, demo, and the design notes: https://github.com/ayeshLK/module-termui. If you build a CLI with it, I would love to hear what got in your way.

The "what I learned" paragraph is the strongest part for readers outside the Ballerina community, so keep it.

## Sources

- [Ballerina community](https://ballerina.io/community)
- [Ballerina moves from Slack to Discord](https://blog.ballerina.io/posts/2022-09-21-ballerina-is-moving-from-slack-to-discord)
- [Publishing packages to Ballerina Central](https://ballerina.io/learn/publish-packages-to-ballerina-central/)
- [ballerina-lang Discussions](https://www.github.com/ballerina-platform/ballerina-lang/discussions)
