---
title: The modules
description: What each of termui's modules is for, and where the API reference is.
sidebar:
  order: 2
---

termui is one package with five modules. Its API reference, with a page per module, is on
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

Importing a module is all it takes to use it. The first build records the release it fetched in
`Dependencies.toml`; later builds pick up newer patch releases on their own and move to a newer minor release
only when you ask. The [compatibility page](../../best-practices/compatibility/) says what each kind of
release may change.

## Next

- [Quick start](../quick-start/): a to-do list in one file.
- [The update and view loop](../../concepts/the-loop/): the idea everything else builds on.
