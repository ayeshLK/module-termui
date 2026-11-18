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
