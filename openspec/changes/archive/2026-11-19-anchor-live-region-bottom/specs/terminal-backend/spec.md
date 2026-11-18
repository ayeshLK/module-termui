# Spec Delta

## ADDED Requirements

### Requirement: Cursor position report
A terminal MAY offer a way to ask for its cursor position. When it does, the system SHALL return the cursor's row and column, counted from zero, or report that the position is unknown when the terminal does not answer within a short time. A terminal that does not offer the capability SHALL be treated as not knowing its cursor position.

#### Scenario: Terminal that reports
- **WHEN** the application asks a real terminal that supports cursor position reports for its position
- **THEN** it receives the row and column of the cursor

#### Scenario: Terminal that does not answer
- **WHEN** the application asks a terminal that never replies
- **THEN** the answer is "unknown" after a short timeout, the application is not blocked indefinitely, and input that arrives meanwhile is not lost

#### Scenario: Output-only terminal
- **WHEN** the application asks a terminal that has no cursor position capability, such as one that can only be written to
- **THEN** the position is treated as unknown

### Requirement: Cursor position replies are not mistaken for keys
The system SHALL recognize a cursor position reply only while a request is outstanding, and SHALL otherwise decode the same bytes as keyboard input.

#### Scenario: Reply to a request
- **WHEN** a request is outstanding and the terminal sends a reply
- **THEN** the reply is consumed as the answer and no key event is produced

#### Scenario: The same bytes as a key
- **WHEN** no request is outstanding and the terminal sends the bytes that look like a reply (for example the sequence for Ctrl+F3)
- **THEN** a key event is produced as before

### Requirement: In-memory terminal reports its cursor
The in-memory terminal SHALL report its exact cursor position so that code depending on it can be tested without a real terminal.

#### Scenario: Position after output
- **WHEN** a test writes output to the in-memory terminal and asks for the cursor position
- **THEN** the answer matches where the cursor is on its virtual screen
