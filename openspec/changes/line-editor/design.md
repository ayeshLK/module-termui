# Design

## Context

See proposal.md for why. The harness input today is a string, a history array and a few key checks in
`update`. The renderer has no hardware-cursor placement (the live region is spans), so the cursor has
to be drawn as a styled cell. `text:displayWidth` and `text:Style.reverse` already exist, and
`PasteEvent` arrives as one event, so the editor needs nothing new from the terminal.

## Goals / Non-Goals

**Goals:**
- A small, pure, testable editor that any program can drop into `update`/`view`.
- Familiar readline-style keys, including multi-line input for prompts.

**Non-Goals:**
- No undo/redo, kill ring, selection, mouse, vi mode, completion or syntax highlighting.
- No hardware cursor placement (would need a renderer capability; post-v1).
- No key remapping in 1.0; the bindings below are fixed and documented.

## Decisions

**1. A new submodule, `ayesha/termui.input`.** It depends on `term` (events) and `text` (width, spans)
and not on the runtime, which keeps it usable and testable alone and follows the existing split.
Alternative: put it in the root module; rejected because the root is the runtime. The name does not clash
with `term`'s input decoding, which is not public.

**2. A class that holds state, handled one event at a time.**

```
LineEditor                                                   // an isolated class
  init(boolean multiline = true, string[] history = [], int maxHistory = 100)
  handleEvent(term:KeyEvent|term:PasteEvent) returns EditResult   // "edited" | "ignored" | Submitted
  text() / cursor()                                           // inspect
  render(int width, string prompt = "> ", text:Style style = {}) returns text:Span[][]
Submitted = record {| string text; |}
```

A class is the natural shape for the program's own state (single strand, like the harness model).
It is an `isolated` class: `Program` is isolated, so a program's field of a non-isolated class type
cannot be initialised (found while testing). The logic lives in plain isolated functions over a state
record, and the class guards that record with a lock. The method is `handleEvent`, not `handle`,
because `handle` is a reserved word in Ballerina.
The result tells the program whether to redraw, whether it was submitted, or whether the key is for
it (Ctrl+C, Escape, Ctrl+D). Alternative: immutable value in, value out; rejected as heavier for
every key and no safer, since the program already owns one strand.

**3. Text model.** The text is held as characters (code points) with the cursor as an index, treating
a character plus the zero-width characters after it (combining marks) as one unit for movement and
deletion, using `displayWidth` to recognise them. Full grapheme segmentation (ZWJ emoji sequences,
regional indicators) is out of scope; the documented limit is that a ZWJ sequence takes several steps.
Line breaks are `\n` characters in the same text; lines are derived when needed.

**4. Key bindings (fixed).**

| Action | Keys |
|---|---|
| Submit | Enter |
| Line break (multi-line) | Alt+Enter, Ctrl+J |
| Left / right | arrows, Ctrl+B / Ctrl+F |
| Word left / right | Alt+B / Alt+F, Ctrl+arrows, Alt+arrows |
| Line start / end | Home, Ctrl+A / End, Ctrl+E |
| Delete back / forward | Backspace / Delete, Ctrl+D when the text is not empty |
| Delete word back / forward | Ctrl+W / Alt+D |
| Delete to start / end of line | Ctrl+U / Ctrl+K |
| Up / down | move between lines; at the first/last line walk the history |
| Ignored (the program decides) | Ctrl+C, Escape, Tab, Ctrl+D on empty text, everything else |

Shift+Enter is not distinguishable from Enter on most terminals, so Alt+Enter and Ctrl+J are the line
break keys. (The kitty keyboard protocol would allow Shift+Enter; post-v1.)

**5. Drawing.** `render` splits the text at line breaks, prefixes the first row with the prompt and later
rows with spaces of the prompt's width, hard-wraps each line by display width (never splitting a wide
character), and draws the cursor as a `reverse` cell on the character under it, or a reverse space at
the end. It returns spans, so the program just concatenates it into `view`.

**6. History.** Held inside the editor; submit adds unless blank or equal to the newest entry; Up/Down
walk it only from the first or last line; the unsent draft is saved on the first Up and restored after
the newest entry. The program can read and seed the history so it can persist it itself (no file I/O
in the library).

## Risks / Trade-offs

- [Terminals send different bytes for Alt+arrows and Alt+Enter (macOS Option often needs a setting)] →
  support several encodings (Ctrl+arrows, Alt+B/F, Ctrl+J), check what the decoder already reports, and
  document the macOS setting.
- [Reverse-cell cursor hides the real cursor position for screen readers] → accepted for 1.0; hardware
  cursor is a later renderer capability.
- [The key table becomes the API users expect to stay] → it is part of the 1.0 freeze, so it is kept small.

## Open Questions

- Whether `maxHistory` needs a default other than 100 (changeable without affecting the specs).
