---
title: Install and run
description: Add termui to a Ballerina package and run a first program.
sidebar:
  order: 1
---

termui is a Ballerina package on
[Ballerina Central](https://central.ballerina.io/ayesha/termui/1.0.0). It needs Ballerina 2201.14 and
JDK 25, and runs on macOS and Linux.

Import it and Ballerina fetches it on the next build. To pin a version, add it to your package's
`Ballerina.toml`:

```toml
[[dependency]]
org = "ayesha"
name = "termui"
version = "1.0.0"
```

The package has five modules. Its API reference, with a page per module, is on
[Ballerina Central](https://central.ballerina.io/ayesha/termui/1.0.0):

| Module | What it is for |
|---|---|
| `ayesha/termui` | The runtime: `Program`, `run`, messages, commands, effects, prompts, `Interface` |
| `ayesha/termui.term` | The terminal: `UnixTerminal`, `FakeTerminal`, input events, environment detection |
| `ayesha/termui.render` | Drawing: the inline renderer, the plain renderer, the cell buffer |
| `ayesha/termui.text` | Styled text, display width, wrapping |
| `ayesha/termui.input` | `LineEditor`: a text input with cursor movement, word editing, multi-line and history |

The site explains how the pieces fit together. For the signature of a type or function, use the API
reference.

## Next

- [The update and view loop](../../concepts/the-loop/): the idea everything else builds on.
- [Tutorial](../../tutorial/): build a small agent harness step by step, starting with a counter.
