# Design

## Context

See proposal.md. Releases are manual (the `Releases are manual and reproducible` requirement) and the
user performs them. This change adds documents and a checklist, not code. It depends on `api-audit-v1`
(the migration note) and `line-editor` (the feature set the changelog describes).

## Goals / Non-Goals

**Goals:**
- A reader can tell what 1.x promises and what it does not.
- A release has a short checklist that cannot be skipped by accident.

**Non-Goals:**
- No automation of the changelog or the checklist; a maintainer reads and ticks them.
- No change to the release workflow itself.

## Decisions

**1. Where the documents live.** `COMPATIBILITY.md` at the repository root, linked from the README
(it is what users read) and from `CONTRIBUTING.md` (what maintainers follow). `CHANGELOG.md` at the
root in the Keep a Changelog layout, newest first. The checklist is a section of `CONTRIBUTING.md`
next to the release steps. Alternative: put the policy in the README; rejected to keep the README short.

**2. Public API means the documented symbols.** Because Ballerina cannot hide cross-module helpers
(see `api-audit-v1`), the policy covers every public symbol but lets those labelled low-level in the
module pages change in a minor release with a changelog notice. Everything supported is frozen until 2.0.

**3. Deprecation uses Ballerina's `@deprecated` annotation** plus a changelog line, kept for at least
one minor release and removed only in a major one.

**4. Supported platforms.** macOS and Linux with the Ballerina version pinned in `gradle.properties`
and the previous Swan Lake Update, as CI allows; Windows is stated as unsupported for 1.0.

**5. The terminal checks are listed, not required to pass everywhere.** tmux and one Linux terminal
are run by hand and the result noted in the release PR; a failure blocks the tag only if it breaks
a documented behaviour.

## Risks / Trade-offs

- [The policy promises more than the project can keep] → keep it short and keep the low-level carve-out.
- [The changelog drifts] → the checklist requires the entry, and archived OpenSpec changes make
  reconstructing it easy.

## Results of the terminal checks (2026-11-19)

Run for task 2.2 with the agent harness built against termui 0.4.0 and `anchorBottom` on.

| Where | Result |
|---|---|
| macOS Terminal, iTerm2 (run by hand earlier, for the 0.2.0 anchoring work) | input on the bottom rows, banner kept, approval prompts and Esc work |
| tmux 3.6 on Linux (Debian-based container, JDK 25, aarch64), `examples/agent-harness/tmux_check.sh` | all 12 checks pass: banner and prompt, input on the bottom rows at the first frame and after a turn, cursor keys, Alt+Enter, Ctrl+U/Ctrl+K, a resize from 100x40 to 60x30, both approval prompts, the streamed answer, Ctrl+D |
| A Linux terminal emulator (GNOME Terminal, xterm, Konsole) | not run: there is no Linux desktop here. Decided on 2026-11-19 that tmux on Linux is enough for now. |

Found while running them: a line of the live region wider than the terminal is cut off at the right edge
and not wrapped (at 60 columns the harness's 64-character status line loses its last word). That is how
the cell buffer has always behaved; it was only mentioned in a code comment, so it is now documented in
the render module page and the README as a known limit.
