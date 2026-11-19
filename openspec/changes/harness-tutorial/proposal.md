# Proposal

## Why

The documentation site promises a tutorial that builds a small agent harness, but only step 1 (a counter) exists. The tutorial index lists steps 2 to 6 as "coming", and a reader who finishes the counter has nowhere to go. The harness is the library's showcase: a prompt, streamed answers, tool calls with approval, a status line and tests. Building it step by step is the clearest way to teach how the pieces fit together, and each step doubles as a regression test of the documented API.

## What Changes

- Add tutorial steps 2 to 6, each a page in the site and a complete program under `examples/tutorial/`:
  2. **A prompt**: `LineEditor` with history; a submitted line is committed above the prompt.
  3. **Streaming output**: a scripted "model" runs as an effect and streams an answer as messages; finished lines are committed, the partial line is live.
  4. **Status and interrupt**: a timer-driven spinner and elapsed time, and Esc to interrupt, with the idle-cost rules applied.
  5. **Tool calls with approval**: `session.confirm` before a tool runs, with the headless default-deny behaviour.
  6. **Testing it**: the harness under a `FakeTerminal` and run headless, with tests that pass in CI.
- Use a scripted model throughout, so the tutorial needs no account, key or network, and say how a real model would plug into the same effect.
- Every step program is compiled in CI (and steps with tests run them); the pages include the files rather than copying them.
- Add a recording of each of the steps 3 to 5, made from the real programs, and a small shared recorder script.
- Replace the "coming soon" entries on the tutorial index and the step 1 page with real links, and add a final "where to go next" section that points to `examples/agent-harness` and the API reference.

Out of scope: a bridge to a real LLM or to Ballerina's AI module, new library API (the tutorial uses only 1.0.0), and changes to `examples/agent-harness` itself.

## Capabilities

### New Capabilities

None.

### Modified Capabilities
- `docs-site`: the tutorial section becomes complete: it ends in a working harness, runs without credentials, and every step's behaviour is checked in CI.

## Impact

- `site/src/content/docs/tutorial/` gains five pages; the index and step 1 page are updated.
- `examples/tutorial/` gains five packages (about 100 to 300 lines each); `examples/check.sh` builds them and runs their tests.
- `site/public/casts/` gains up to three casts; a recorder script is added.
- No package code, API or release is affected.
