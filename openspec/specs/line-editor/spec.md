# line-editor Specification

## Purpose
A text input for terminal programs, driven by key and paste events and testable without a terminal: readline-style editing and cursor movement, deleting by word and line, multi-line input, paste as one edit, a history of submissions, and drawing the text with a visible cursor wrapped to the width.

## Requirements

### Requirement: Editing text from key events
The system SHALL provide a text editor that holds a text and a cursor, changes them in response to key and paste events, and reports what happened, without needing a terminal. Printable keys SHALL insert at the cursor, Backspace SHALL remove the character before it and Delete the character after it.

#### Scenario: Typing
- **WHEN** the keys `h` and `i` are handled on an empty editor
- **THEN** the text is `hi` and the cursor is after the `i`

#### Scenario: Backspace and delete
- **WHEN** the cursor is between `a` and `b` in `ab` and Backspace is handled, and then Delete
- **THEN** the text is empty

#### Scenario: Unhandled keys
- **WHEN** a key the editor does not use, such as Ctrl+C or Escape, is handled
- **THEN** the editor reports that it ignored it and the text is unchanged, so the program can act on it

### Requirement: Moving the cursor
The system SHALL move the cursor by character (left and right), by word, and to the start and end of the line, using the common keys (arrows, Home and End, Ctrl+A and Ctrl+E, Ctrl+B and Ctrl+F, and Alt or Ctrl with the arrows for words). A character SHALL include any combining marks attached to it, so the cursor never stops between a letter and its mark.

#### Scenario: Word movement
- **WHEN** the cursor is at the end of `one two` and word-left is handled twice
- **THEN** the cursor is at the start of `one`

#### Scenario: Combining mark
- **WHEN** the text is a letter followed by a combining accent and the cursor moves left from the end
- **THEN** it moves before the letter in one step

#### Scenario: Edges
- **WHEN** the cursor is at the start and left is handled
- **THEN** nothing changes

### Requirement: Deleting by word and line
The system SHALL delete the word before the cursor (Ctrl+W), the word after it (Alt+D), everything from the cursor to the end of the line (Ctrl+K) and everything from the start of the line to the cursor (Ctrl+U).

#### Scenario: Delete word
- **WHEN** the text is `one two` with the cursor at the end and Ctrl+W is handled
- **THEN** the text is `one `

#### Scenario: Kill to end
- **WHEN** the cursor is after `one` in `one two` and Ctrl+K is handled
- **THEN** the text is `one`

### Requirement: Submitting and multi-line text
The system SHALL submit the text when Enter is handled, report the submitted text, and leave the editor empty. In multi-line mode the system SHALL insert a line break for Alt+Enter and Ctrl+J instead, and Up and Down SHALL move between lines; in single-line mode those keys SHALL be ignored for line breaks.

#### Scenario: Submit
- **WHEN** the text is `hello` and Enter is handled
- **THEN** the editor reports `hello` as submitted and its text is empty

#### Scenario: Line break
- **WHEN** a multi-line editor holds `a` and Alt+Enter and then `b` are handled
- **THEN** the text is `a`, a line break, `b`, and nothing was submitted

#### Scenario: Single-line mode
- **WHEN** a single-line editor handles Alt+Enter
- **THEN** no line break is inserted

### Requirement: Paste as one insertion
The system SHALL insert pasted text at the cursor as one edit. Line breaks in pasted text SHALL be kept in multi-line mode and replaced by spaces in single-line mode, and carriage returns SHALL be normalised to line feeds. Pasted text SHALL NOT submit.

#### Scenario: Multi-line paste
- **WHEN** `x\r\ny` is pasted into an empty multi-line editor
- **THEN** the text is `x`, a line break, `y` and nothing was submitted

#### Scenario: Single-line paste
- **WHEN** `x\ny` is pasted into an empty single-line editor
- **THEN** the text is `x y`

### Requirement: History
The system SHALL keep a history of submitted texts and let Up and Down walk through it when the cursor is on the first or last line, keeping the unsent draft so walking back past the newest entry restores it. A blank text and a repeat of the newest entry SHALL NOT be added, and the history SHALL be limited to a configurable number of entries.

#### Scenario: Walk through history
- **WHEN** `one` and `two` were submitted and Up is handled twice, then Down once
- **THEN** the text is `two`

#### Scenario: Draft is kept
- **WHEN** the user typed `dra`, pressed Up, and then Down
- **THEN** the text is `dra` again

#### Scenario: No duplicates
- **WHEN** `one` is submitted twice in a row
- **THEN** the history holds it once

### Requirement: Drawing the editor
The system SHALL produce the editor's lines as styled text for a given width, with a prompt on the first line and an indent of the same width on later lines, wrapping long lines by display width, and SHALL show the cursor as a reverse-video cell (a space when the cursor is at the end). Wide characters SHALL NOT be split across rows.

#### Scenario: Cursor in the middle
- **WHEN** the text is `abc` with the cursor on `b`
- **THEN** the drawn line shows `b` with reverse style and the other characters unstyled

#### Scenario: Wrapping
- **WHEN** the text is longer than the width
- **THEN** it continues on the next row and the cursor is drawn on the right row and column

#### Scenario: Wide character at the edge
- **WHEN** a double-width character would start in the last column
- **THEN** it moves to the next row whole

### Requirement: Works in a program
The system SHALL let a program use the editor from its `update` and `view`, with keys and pastes arriving as messages, and SHALL be testable with the in-memory terminal.

#### Scenario: Typing in a running program
- **WHEN** a program feeds the editor from its messages and the in-memory terminal receives `hi` and Enter
- **THEN** the program sees `hi` submitted and the editor's drawn lines show the empty editor again
