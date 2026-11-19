# Compatibility and versioning

termui follows [semantic versioning](https://semver.org). This page says what that promises, so you
can decide how to depend on it. From 1.0.0 on, a change that breaks what is described here is made only
in a new major version.

## What is public API

Everything documented in the module pages is supported API:

| Module | Supported |
|---|---|
| [`ayesha/termui`](ballerina/Module.md) | `Program`, `run`, `Options`, `Interface`, `Session`, `Message`, `Command` and its helper functions, and the message types the runtime sends |
| [`ayesha/termui.term`](ballerina/modules/term/Module.md) | `Terminal`, `CursorReporter`, the input events and keys, `UnixTerminal`, `StreamTerminal`, `FakeTerminal`, `Environment` and its functions |
| [`ayesha/termui.render`](ballerina/modules/render/Module.md) | `Renderer`, `InlineRenderer`, `PlainRenderer`, the cell buffer used to inspect a frame |
| [`ayesha/termui.text`](ballerina/modules/text/Module.md) | `Span`, `Style`, the color types, `displayWidth`, `wrap`, `wrapText`, `plainText`, `toAnsi` |
| [`ayesha/termui.input`](ballerina/modules/input/Module.md) | `LineEditor`, `EditResult`, `Submitted` and its key bindings |

Each module page has a **Stability** section. A symbol the page calls *low-level* (for example
`text:sgr`) is public only because another module of the package needs it. It is covered by the rules
below except that it may change in a minor release, with a note in the [changelog](CHANGELOG.md).
Anything that is not public in the source, and the exact text and escape sequences the renderer writes
(they may be optimised), are not API.

## What each kind of release may do

| Release | May contain |
|---|---|
| **Patch** (1.0.1) | Bug fixes, documentation, performance, with no change to documented behaviour |
| **Minor** (1.1.0) | Everything in a patch, plus additions: new functions, types, options with defaults, messages, commands, keys, events, and optional capabilities. Deprecations. Changes to low-level symbols, announced in the changelog. |
| **Major** (2.0.0) | Removal of deprecated symbols and any other breaking change |

Additions never break a program that follows two rules, which the module pages repeat:

- **Handle the messages and events you know and ignore the rest.** New message, event and key types
  appear in minor releases.
- **Implement only the documented methods of `Renderer` and `Terminal`.** These two types have a fixed
  set of required methods. New abilities arrive as separate optional capability types (as
  `CursorReporter` did), which the runtime uses only when your implementation also provides them.

The defaults of the run settings (`colors`, `reflow` and `interactive` on, `anchorBottom` off,
`pollInterval`, `maxPollInterval`, `fallbackSize`) are part of the API and stay for the whole major version.

## Deprecation

A symbol that is going away is first marked with Ballerina's `@deprecated` annotation in a minor
release, with its replacement named in the annotation and the changelog. It keeps working until the
next major release and is removed no earlier than that.

## Supported platforms

- **Operating systems:** macOS and Linux. Windows is not supported.
- **Ballerina:** the version pinned in [`gradle.properties`](gradle.properties) (currently 2201.14.2,
  which needs JDK 25) is what the tests run on, and a daily build checks the latest release. Other
  versions may work but are not tested.
- **Terminals:** any terminal that understands ANSI escape sequences. Bottom anchoring also needs one
  that answers the cursor position request; without it, the option has no effect and the live region
  stays where it is.

A change to this list is made in a minor release and noted in the changelog.

## Before 1.0

Releases before 1.0.0 (0.x) made no such promise: minor versions could break the API. The changes that
did are listed in the [changelog](CHANGELOG.md).
