## ADDED Requirements

### Requirement: The terminal size is the first message
The system SHALL deliver the size it is drawing with to the program as a resize event before any other message, so the program knows the width and height from its first view. The size SHALL be the terminal's when it reports a usable one and the fallback the runtime draws with otherwise. The system SHALL keep delivering a resize event whenever the size changes.

#### Scenario: First message
- **WHEN** a program is run on a terminal that is 100 columns by 30 rows
- **THEN** the first message the program receives is a resize event of 100 by 30, before any key event, and the program's first view is built after it

#### Scenario: Size unknown
- **WHEN** the terminal cannot report its size or reports zero
- **THEN** the first message is a resize event with the fallback size the renderer uses

#### Scenario: Not a real resize
- **WHEN** the initial size is delivered
- **THEN** nothing is written to the terminal because of it: no clearing, no redraw beyond the program's first frame

#### Scenario: Later changes
- **WHEN** the window is resized after the program started
- **THEN** the program receives a resize event with the new size, as before

#### Scenario: Without an interactive terminal
- **WHEN** a program is run with its output redirected or with no terminal
- **THEN** it still receives the size the runtime uses as its first message
