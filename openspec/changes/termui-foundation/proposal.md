# Proposal

## Why

Agentic CLIs (claude-code, Codex, and similar) have raised the bar for terminal UX: streaming output, a live-updating input area, inline approval prompts, and scrollback that stays intact. Ballerina has no toolkit for building such interfaces, so developers building agentic apps in Ballerina would have to implement raw terminal handling themselves. `ayesha/termui` provides that foundation as a UI/CLI toolkit only: it does not include agent logic, which stays in the application.

## What Changes

- Introduce the `ayesha/termui` package foundation, written in pure Ballerina and targeting macOS and Linux first:
  - A `Terminal` abstraction with a Unix backend (raw mode via `stty`, key decoding from `/dev/tty`, ANSI output) and a fake in-memory backend for tests and headless use.
  - Text primitives: styles, unicode-aware width, and ANSI-aware wrapping.
  - A Ratatui-inspired renderer: a cell buffer with diffing, an inline viewport (a redrawn live region at the bottom), a commit-above operation that writes finished output into scrollback, resize handling, and a plain-text renderer for non-interactive use.
  - A pragmatic MVU runtime: a single loop that owns the model, a lock-guarded event queue fed by input, effects, and ticks, `readonly` messages across strands, and frame coalescing so bursts of events produce one redraw.
  - Headless behavior: mode detection (tty or not, `NO_COLOR`, `TERM=dumb`), UI drawn to the tty or stderr while results go to stdout, and a `NoTerminal` error for prompts that cannot be answered.
- Resolve a set of feasibility questions through an initial spike that gates the rest of the work (see `design.md`).
- Out of scope: agent loop, tool registry, permissions, sessions, or any LLM integration; a declarative component layer; a general layout solver; structured (JSON/NDJSON) output; a JLine or Java-shim backend; Windows support; the widget set (editor, select, spinner) and markdown rendering; native-image as a first-release requirement (it is a v1 goal and a design constraint).

## Capabilities

### New Capabilities
- `terminal-backend`: acquiring, configuring, reading from, and restoring the terminal, including the fake backend and mode detection.
- `text-primitives`: terminal text styling, display width, and wrapping.
- `buffer-renderer`: the cell buffer, diffing, inline viewport, commit-above, resize handling, and plain renderer.
- `mvu-runtime`: the message loop, event queue, effects, and frame coalescing that drive an application.
- `headless-mode`: behavior when no interactive terminal is available.

### Modified Capabilities

None.

## Impact

- New package modules `text`, `term`, `render`, and the root runtime under `ayesha/termui`, importing only `io`, `os`, `time`, and `lang.*` standard library modules to keep startup light.
- Depends on `termui-scaffold` for the build, test, and CI setup.
- No existing code or specs are affected, because the project has none yet.
- Consumers: agentic apps and CLIs written in Ballerina, which will later layer widgets and an AI-module seam on top.
