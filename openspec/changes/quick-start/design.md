# Design

## Context

See proposal.md for why. The tutorial's step 1 is the counter and step 2 already uses `input:LineEditor` for a prompt, so the to-do list reuses ideas the reader meets there but is a different, complete program. Page code is included from compiled example files by region markers (`// region name`), and `examples/check.sh` builds and tests each example package. Recordings come from a pty recorder (`examples/tutorial/record.py`).

## Goals / Non-Goals

**Goals:**
- A reader can read the page top to bottom, type the program in, and have a working app within a few minutes.
- The program is short enough to show in four named pieces without scrolling through a wall of code.

**Non-Goals:**
- Teaching commands, timers, effects or testing. The page links to them.
- A feature-rich to-do app (editing an item, priorities, filters).

## Decisions

**Two modes.** The program has a browsing mode (up and down select, space toggles, `d` deletes, `a` starts an add, `q` quits) and an adding mode (a `LineEditor`; enter appends, escape cancels). One mode would clash with the line editor's use of up and down for history. Alternative: always show the input and select with Tab; rejected as less obvious than a mode.

**Persistence lives in `main`, not in the program.** `main` reads `todos.json` (an empty list when the file is missing), runs the program with the items, and writes the items back when `run` returns. This needs no commands or effects, and shows that `run` returns when the user quits. Alternative: save after every change through a command; rejected here because it brings in commands before the reader has a reason for them. A corrupt file is reported as an error from `main`, not silently replaced.

**The final list is committed to the scrollback on quit.** `q` returns a command that writes the list as prose before quitting, so the list stays on screen after exit. It demonstrates inline rendering with no extra explanation.

**The page shows the program in pieces.** State, `update`, `view` and `main` regions of one file, followed by the whole file collapsed or linked, as in the tutorial's first step. The example is its own package (`examples/quick-start`) with a test that scripts keys against a fake terminal and checks the saved file, so the behaviour the spec names is tested.

**The old address is not redirected.** Nothing outside the site links to `start/install`; the home page's button is the only inbound link. The site is new enough that a redirect is not worth its upkeep.

## Risks / Trade-offs

- The program is longer than the counter, about 90 lines → show it in regions, and keep features to add, toggle, delete and quit.
- Writing the file in `main` means a crash loses the session's changes → acceptable for a quick start, and the page says when the file is saved.
- Overlap with the tutorial's prompt step → the to-do list is a finished app and stays out of the harness path; the tutorial links to it rather than repeating it.

## Open Questions

None.

## Resolved

**The piped run is left off the page.** Tried with the built jar: with piped input (`printf 'a\nbuy milk\n\rq' | java -jar ...`) and with output redirected (`</dev/null | cat`), the program does not take the piped bytes as keys; it prints the one frame ("Nothing to do. Press a to add an item." and the key hint) and exits, and the saved file is `[]`. Showing that would suggest the program works in a pipe in a useful way, which for a key-driven list it does not. The headless-modes concept page covers how programs behave without a terminal; the quick start links to it.
