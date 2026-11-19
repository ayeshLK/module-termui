# buffer-renderer Specification

## Purpose
Defines how an application draws to the terminal: a redrawn live region at the bottom, finished output committed into scrollback, minimal writes between frames, and correct behavior on resize, with a plain-text renderer when no interactive terminal is available.

## Requirements

### Requirement: Cell buffer with minimal updates
The system SHALL render each frame into a grid of styled cells and SHALL write to the terminal only the cells that changed since the previous frame.

#### Scenario: Unchanged frame
- **WHEN** a frame is identical to the previous one
- **THEN** nothing is written to the terminal

#### Scenario: One cell changed
- **WHEN** a single cell differs between frames
- **THEN** only the output needed to update that cell is written

### Requirement: Inline live region
The system SHALL draw the live region inline at the bottom of the terminal without switching to the alternate screen, leaving prior terminal content and scrollback untouched.

#### Scenario: Start of a session
- **WHEN** the live region is first drawn
- **THEN** the content above it, including the user's earlier shell output, is unchanged

#### Scenario: Region height changes
- **WHEN** the live region grows or shrinks between frames
- **THEN** the terminal shows exactly the new region with no leftover lines

### Requirement: Commit above the live region
The system SHALL let the application commit finished output so it is written once into the terminal's scrollback above the live region and is never redrawn by the system.

#### Scenario: Commit while live region is shown
- **WHEN** the application commits a block of text
- **THEN** the block appears above the live region and the live region stays at the bottom

#### Scenario: Prose wrapping
- **WHEN** the application commits a prose paragraph
- **THEN** it is written as a logical line so the terminal can wrap and reflow it

#### Scenario: Structured blocks
- **WHEN** the application commits a structured block such as a table, box, or diff
- **THEN** it is written pre-wrapped to the width at commit time

### Requirement: Resize handling
The system SHALL redraw the live region correctly after a resize, clearing the rows the previous region now occupies after any terminal reflow, and SHALL NOT re-lay-out committed history.

#### Scenario: Window narrowed
- **WHEN** the terminal is narrowed so the old live region wraps onto more rows
- **THEN** after the next frame no stale or duplicated live-region rows remain

#### Scenario: Window widened
- **WHEN** the terminal is widened
- **THEN** the live region is redrawn at the new width and committed history is left as written

### Requirement: Full-screen mode
The system SHALL offer an alternate-screen mode for full-screen interfaces that restores the previous screen contents on exit.

#### Scenario: Entering and leaving
- **WHEN** an application enters and then leaves full-screen mode
- **THEN** the terminal shows its prior content as before entering

### Requirement: Plain renderer
When output is not an interactive terminal, the system SHALL render committed items as sequential plain-text lines without cursor control or styling, and SHALL omit or collapse transient live-region content.

#### Scenario: Output piped to a file
- **WHEN** the application commits two blocks while stdout is redirected to a file
- **THEN** the file contains the two blocks as plain lines in order, with no escape sequences

#### Scenario: Transient content
- **WHEN** the live region contains a spinner and the output is not interactive
- **THEN** the spinner is not written repeatedly

### Requirement: Testable frames
The system SHALL allow the rendered frame to be inspected as text, including each cell's style, when running against the in-memory terminal.

#### Scenario: Asserting on a frame
- **WHEN** a test renders a view to the in-memory terminal
- **THEN** it can compare the frame's text and styles to expected values

### Requirement: Bottom-anchored live region
When the application enables bottom anchoring and the terminal reports where its cursor is, the system SHALL place the live region on the last rows of the terminal on the first draw without changing any content above it. Anchoring SHALL be off by default.

#### Scenario: Room below the existing output
- **WHEN** the live region is first drawn with anchoring enabled and there are more free rows below the cursor than the region needs
- **THEN** the region occupies the last rows of the terminal, the blank rows between the output and the region are left empty, and no content moves

#### Scenario: Cursor near the bottom
- **WHEN** the live region is first drawn with anchoring enabled and the cursor is within the region's height of the bottom
- **THEN** the screen scrolls by only the number of rows the region lacks, and no existing content is overwritten

#### Scenario: Anchoring not requested
- **WHEN** the live region is drawn without enabling anchoring
- **THEN** it starts on the cursor's row, exactly as before

### Requirement: Blank rows are used before the screen scrolls
While there are blank rows between the output and an anchored live region, the system SHALL use them for committed output and for the region's growth before scrolling anything, and a shrinking region SHALL return its rows to them so the region keeps the last row.

#### Scenario: Commit fits in the blank rows
- **WHEN** the application commits fewer rows than there are blank rows above the region
- **THEN** the output appears directly below the existing content, the region does not move, and nothing scrolls

#### Scenario: Region grows
- **WHEN** an anchored region grows and there are blank rows above it
- **THEN** it grows upward into them, the rows already drawn at the bottom stay where they are, and nothing scrolls

#### Scenario: Region shrinks
- **WHEN** an anchored region shrinks
- **THEN** its last row stays on the last row of the terminal, the vacated rows become blank rows above it, and no blank row remains below it

#### Scenario: Commit longer than the blank rows
- **WHEN** the application commits more rows than there are blank rows
- **THEN** the blank rows are filled first, the rest of the output scrolls the screen normally, and no blank row is scrolled into the scrollback

#### Scenario: Wrapped prose
- **WHEN** the application commits a prose paragraph that the terminal wraps onto several rows
- **THEN** all of those rows count against the blank rows

### Requirement: Scrolling after the blank rows are used up
When no blank rows remain above an anchored live region, the system SHALL scroll output exactly as an unanchored region does, and everything that scrolls off the top, including content from before the session, SHALL remain in the terminal's scrollback.

#### Scenario: Blank rows exhausted
- **WHEN** committed output has filled every blank row and more output is committed
- **THEN** the screen scrolls one row per output row, the region stays on the last row, and the earlier output and banner can be reached in the scrollback

### Requirement: Anchoring depends on a known cursor position
Bottom anchoring SHALL have no effect unless the terminal reports its cursor position, and SHALL have no effect on the plain renderer, on output that is not an interactive terminal, or in full-screen mode.

#### Scenario: Terminal does not report its cursor
- **WHEN** anchoring is enabled and the terminal does not answer a cursor position request
- **THEN** the region is drawn exactly as it would be without anchoring

#### Scenario: Not an interactive terminal
- **WHEN** anchoring is enabled and output is plain, piped, or headless
- **THEN** output is identical to the output without anchoring

### Requirement: Re-anchoring after a resize
After a resize the system SHALL clear the old region as it does without anchoring, and SHALL anchor the region again at the next draw using the cursor position reported at that time.

#### Scenario: Window resized
- **WHEN** the terminal is resized and the application draws again
- **THEN** the region is on the last rows of the new size and no rows of the old region remain

### Requirement: The renderer contract is frozen and extended by capabilities
The system SHALL treat the methods of the `Renderer` type (draw, commit prose, commit block, resize, close) as the complete required contract for a renderer, and SHALL offer any further ability, now or later, as a separate optional capability type that a renderer may also implement.

#### Scenario: Minimal renderer
- **WHEN** an application passes a renderer that implements only the required methods to the runtime
- **THEN** the program runs, drawing and committing through those methods

#### Scenario: Optional ability
- **WHEN** a renderer implements an optional capability
- **THEN** the runtime uses it, and a renderer that does not implement it is not affected

### Requirement: Cell buffer is the supported way to inspect a frame
The system SHALL document the cell buffer and its inspection functions as the supported way to examine a rendered frame, including each cell's style, and SHALL keep them public for that purpose.

#### Scenario: Inspecting a frame in a test
- **WHEN** a test builds a buffer from styled lines
- **THEN** it can read the text of each row and the character and style of each cell
