# Proposal

## Why

An agent-style CLI is built around a text input, yet termui ships none: the agent harness hand-rolls one (append, backspace, history) with no cursor movement, no word editing and no multi-line input, and every application would have to do the same. It is the most visible gap against the library's pitch, and a good input is what makes a prompt feel finished.

## What Changes

- A line editor as pure state: it takes `KeyEvent` and `PasteEvent` values and produces its new state and the styled spans to draw, including the cursor, so it needs no terminal and is tested like the rest.
- Editing: insert, delete, backspace, left/right, home/end, word movement and word delete, delete to line start or end, paste as one insertion, history navigation, and a way to enter a newline for multi-line input (for example Alt+Enter) with the usual Enter to submit.
- It copes with wide and combining characters (cursor and wrapping use the existing display-width rules) and with text longer than the width.
- The agent-harness example drops its hand-written input and uses the editor.

## Capabilities

### New Capabilities
- `line-editor`: editing behaviour of a single- and multi-line text input driven by key events, with history and paste.

### Modified Capabilities

## Impact

- A new public surface (module placement is a design decision: likely a new submodule, e.g. `ayesha/termui.input`), tests on `FakeTerminal`, docs and README, `examples/agent-harness/main.bal`.
- Additive: no change to existing APIs. Its public API is part of the 1.0 freeze, so it follows the rules from `api-audit-v1`.
