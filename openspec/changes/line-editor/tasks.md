# Tasks

## 1. Core editing

- [x] 1.1 Create the `ayesha/termui.input` module with `LineEditor`, `EditResult` and `Submitted`, the character model (a character plus its combining marks is one unit), insert, Backspace and Delete; verify with unit tests for the "Editing text" scenarios, including ignored keys
- [x] 1.2 Add cursor movement: characters, words, line start and end, with the key bindings from design.md; verify with tests for the movement scenarios, including combining marks and the edges
- [x] 1.3 Add word and line deletion (Ctrl+W, Alt+D, Ctrl+K, Ctrl+U); verify with the deletion scenarios

## 2. Lines, paste and history

- [x] 2.1 Add submit, multi-line (Alt+Enter, Ctrl+J, Up/Down between lines) and single-line mode; verify with the submit and line-break scenarios
- [x] 2.2 Add paste handling (one insertion, CRLF normalised, line breaks kept or turned into spaces, never submits); verify with the paste scenarios
- [x] 2.3 Add history (Up/Down at the first or last line, draft kept, no blanks or repeats, limit, seed and read-back for the program); verify with the history scenarios

## 3. Drawing

- [x] 3.1 Add `render(width, prompt, style)`: prompt and indent, hard wrap by display width, reverse-cell cursor, wide characters kept whole; verify with the drawing scenarios, including a cursor at the end of a full row
- [x] 3.2 Check that the keys the decoder reports for Alt+Enter, Alt+arrows, Ctrl+arrows and Ctrl+J match the bindings (fix the decoder or the table); verify with decoder tests for each sequence

## 4. In a program

- [x] 4.1 Add a test running a small program that feeds `LineEditor` from its messages on the in-memory terminal (type, paste, edit, submit, history), as in the "Works in a program" scenario; verify the test passes
- [x] 4.2 Once the release containing the editor is published (the examples build against the published package), replace the hand-written input in `examples/agent-harness/main.bal` with `LineEditor`, keeping its commands and history behaviour; verify with `verify.py` on the pty and re-record the demo only if it changed visibly
- [x] 4.3 Document the module in a new `modules/input/Module.md` (keys table, the macOS Option note, the limits), the README module table and `Package.md`; verify the example in the page is covered by a doc test like the other modules

## Workflow follow-up

- Include in the next release (before 1.0), then archive the change. Following the example change rule, update the harness to the released version only after the release.
