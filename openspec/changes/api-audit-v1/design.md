# Design

## Context

See proposal.md for why. Ballerina visibility is per module: a symbol used only inside its own module
can be non-public, one used from another module of the package (the root module uses `term` and
`render`; `render` uses `text`) must be public. So the audit is mostly: find what is public without
needing to be, and write down the rule for growth. No behaviour changes except the removals below.

## Goals / Non-Goals

**Goals:**
- A public surface that contains only supported API or documented low-level pieces other modules need.
- Extension rules that let 1.x add abilities without breaking implementors.
- Settled defaults.

**Non-Goals:**
- No renames: the naming review found nothing worth the churn (below).
- No new features, no behaviour change in rendering or input.

## Decisions

**1. Classification of the public symbols (from a usage search of src, examples and tests).**

| Symbol | Used where | Decision |
|---|---|---|
| `Queue`, `PromptRequest` (root) | only the root module | make non-public (they leak the loop's internals) |
| `probeStdio`, `parseStdioProbe`, `isTerminalPath` (term) | only `term` and its tests | make non-public |
| `environmentFrom` (term) | `term` tests and the root module's tests (builds an `Environment` from variables) | **keep** (found while implementing): the supported way to build an `Environment` for tests; document it as such. `detectEnvironment`, `Environment`, `Mode`, `selectMode` stay |
| `newBuffer`, `bufferFromLines`, `bufferLines`, `cellAt`, `Buffer`, `Cell` (render) | `render` and its tests | **keep**: the supported way to inspect a frame (spec "Testable frames"); document as such |
| `sgr`, `toAnsi`, `plainText` (text) | `render` uses them | keep (needed across modules); document `sgr` as low-level |
| `DEFAULT_WIDTH`, `DEFAULT_HEIGHT` (term) | `term`, as default parameter values of public functions | keep if the compiler needs them public for the defaults, otherwise make non-public |
| `StreamTerminal`, `UnixTerminal`, `FakeTerminal` | root module, tests, users | keep |
| `InputEnded`, `InputFailed`, `EffectFailed`, `NoTerminal` | programs match on them | keep |
| `Interface.renderer`, `.options`, `.result`, `.run` | users | keep |

Re-check (task 1.3): a search of every public symbol against the other modules, the examples and the
tests confirmed the table. Symbols used by no other module and no example (`Cell`, `Buffer`, `newBuffer`,
`bufferFromLines`, `bufferLines`, `cellAt`, `wrapText`) are the frame-inspection and text helpers kept on
purpose; nothing else public was found that only its own module uses.

Exact symbols are confirmed by the compiler while doing the tasks: a symbol that turns out to be needed
across modules stays public and is documented as low-level.

**2. Growth rule (the spec's "Growth is additive").** `Renderer` and `Terminal` stay as they are; a new
ability becomes a new object type that includes the base type (`*Renderer`), as `CursorReporter` did
with `*Terminal` (that form also avoids a compiler problem with narrowing to a bare capability type).
`Command`, `Message`, `InputEvent` and `NamedKey` are unions programs construct or match with `is`
checks and an else path, so adding members is additive; the docs tell programs to ignore what they do
not know. This makes post-1.0 features such as clearing the screen additive (a `Clearable` renderer
capability and a new command). Alternative: seal the types and forbid third-party implementations;
rejected because the `FakeTerminal` and plain renderers show implementing them is a real use.

**3. Defaults stay as they are.** `anchorBottom = false`: anchoring needs a cursor report that costs up
to 200 ms on a terminal that does not answer, and the in-place look is the documented behaviour.
`reflow = true`: most terminals re-wrap. `colors`, `interactive` and `pollInterval` keep their
values. Recorded in the spec so a change needs a major version. Alternative: default to anchored;
rejected for the cost above, and an opt-in can still become the default in 2.0.

**4. Naming review: no renames.** `commitProse`/`commitBlock`, `every`, `batch`, `quit`, `effect`,
`Session.confirm`/`choose` read consistently, and renaming now would break 0.2 users for no gain.
`Interface.run(program, initialCommand, anchorBottom)` keeps its two convenience settings because
colors, reflow and interactivity come from the environment; `Options` stays the full set for the
lower-level `run`.

**5. Prove the rule with tests.** A minimal renderer and a minimal terminal (no optional capabilities)
run a program in the tests, so the contract cannot silently grow a required method.

## Risks / Trade-offs

- [A symbol made non-public is used by someone] → it was never documented as API; the changelog and
  migration note (see `v1-release-readiness`) name each removal.
- [A symbol needed across modules cannot be hidden] → documented as low-level in its module's page.
- [Freezing the defaults is wrong for some users] → settings stay available per run; only the default is fixed.

## Migration

Symbols that stopped being public (none was documented as API, none is used by the examples):

| Module | Symbol | Replacement |
|---|---|---|
| `ayesha/termui` | `Queue` | none (internal to the loop) |
| `ayesha/termui` | `PromptRequest` | none (use `Session.confirm` and `Session.choose`) |
| `ayesha/termui.term` | `probeStdio`, `parseStdioProbe`, `isTerminalPath` | `detectEnvironment`, or `environmentFrom` to build an `Environment` for a test |
| `ayesha/termui.term` | `DEFAULT_WIDTH`, `DEFAULT_HEIGHT` | none (the defaults are 80 by 24) |

Nothing else was removed or renamed. Both examples build against the result.
