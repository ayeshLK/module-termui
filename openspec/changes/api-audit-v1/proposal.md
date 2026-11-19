# Proposal

## Why

1.0 is a promise that the public API will not break without a major version. Several things are public today only because Ballerina has no package-private visibility between modules (`render` and `term` share helpers with the root module), and the extension points were designed one feature at a time: adding a method to the `Renderer` object type or a variant to the `Command` union can break users, and two defaults (`anchorBottom`, `reflow`) cannot be changed later without a break. These are cheap to fix now and expensive after 1.0.

## What Changes

- Audit every public symbol of the four modules. For each: keep and document it as supported API, or move or reshape it so it is not public. Candidates seen so far: `probeStdio`, `parseStdioProbe`, `environmentFrom`, `isTerminalPath`, `StreamTerminal`, `Queue`, `PromptRequest`, the `Buffer`/`Cell` helpers, `sgr`. Anything kept but low-level is labelled as such in its module docs.
- State the extension rule once: new abilities on `Renderer`, `Terminal` and the like arrive as optional capability types (as `CursorReporter` did), and new `Command` variants are additive and documented as such. Align `Renderer` with it if needed. **BREAKING** where a symbol is removed or renamed (0.x, shipped in 0.3.0 before 1.0).
- Decide the defaults of `anchorBottom` and `reflow` for 1.0 and record why.
- Review naming and signatures shipped in 0.1/0.2 (`commitProse`/`commitBlock`, `Every`, `Session.confirm`/`choose`, `Interface.run` taking `anchorBottom` beside `Options`) and fix what is inconsistent.

## Capabilities

### New Capabilities

### Modified Capabilities
- `mvu-runtime`: the stable surface of the runtime (commands, options, session) and the rule for adding to it.
- `buffer-renderer`: the renderer contract as an extension point, and the 1.0 defaults.
- `terminal-backend`: the terminal contract and its optional capabilities.

## Impact

- Public declarations across `ballerina/`, `modules/term`, `modules/render`, `modules/text`; all four `Module.md` files, `Package.md`, README; examples and tests that use renamed or removed symbols.
- A migration note for 0.2 users (feeds `v1-release-readiness`).
