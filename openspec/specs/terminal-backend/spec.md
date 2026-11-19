# terminal-backend Specification

## Purpose
Defines how an application acquires and releases an interactive terminal, reads decoded input events from it, and writes output to it, including an in-memory terminal for tests and non-interactive use.

## Requirements

### Requirement: Terminal acquisition and restoration
The system SHALL put an attached terminal into raw input mode when acquired and SHALL restore the terminal's original settings on release, on normal exit, and on graceful termination.

#### Scenario: Normal release
- **WHEN** an application acquires the terminal and later releases it
- **THEN** the terminal's original mode, echo, and cursor settings are restored

#### Scenario: Graceful termination
- **WHEN** the process receives a graceful stop request while the terminal is acquired
- **THEN** the terminal is restored before the process exits

#### Scenario: Unrecoverable error
- **WHEN** the application fails with an error it can catch while the terminal is acquired
- **THEN** the terminal is restored before the error is reported

### Requirement: Decoded input events
The system SHALL deliver user input as decoded events: printable characters, arrow and navigation keys, function keys, Ctrl and Alt combinations, Esc, and bracketed-paste content.

#### Scenario: Arrow key
- **WHEN** the user presses an arrow key
- **THEN** the application receives a single arrow event, not raw escape bytes

#### Scenario: Lone Esc
- **WHEN** the user presses Esc and no further bytes follow within the input timeout
- **THEN** the application receives an Esc event

#### Scenario: Pasted text
- **WHEN** the user pastes multi-line text into a terminal that supports bracketed paste
- **THEN** the application receives one paste event containing the full text

#### Scenario: Ctrl+C in raw mode
- **WHEN** the user presses Ctrl+C while the terminal is in raw mode
- **THEN** the application receives it as a key event and decides how to respond

### Requirement: Terminal size and resize events
The system SHALL report the terminal's current width and height and SHALL notify the application when they change.

#### Scenario: Initial size
- **WHEN** the terminal is acquired
- **THEN** the application can read the current width and height

#### Scenario: Window resized
- **WHEN** the user resizes the terminal window
- **THEN** the application receives a resize event carrying the new dimensions

### Requirement: Buffered output
The system SHALL write each rendered frame to the terminal as a single flushed write.

#### Scenario: Frame output
- **WHEN** the renderer emits a frame
- **THEN** the terminal receives the frame's bytes in one write, with no partial frame visible

### Requirement: In-memory terminal
The system SHALL provide an in-memory terminal that accepts scripted input events and records rendered output so applications can be tested without a real terminal.

#### Scenario: Scripted keystrokes
- **WHEN** a test supplies a sequence of key events to the in-memory terminal
- **THEN** the application receives them in order as if typed

#### Scenario: Inspecting output
- **WHEN** the application renders a frame to the in-memory terminal
- **THEN** a test can read the resulting screen contents

### Requirement: Terminal environment detection
The system SHALL determine whether standard input and output are interactive terminals and SHALL honor `NO_COLOR` and `TERM=dumb`.

#### Scenario: Output redirected
- **WHEN** standard output is redirected to a file or pipe
- **THEN** the system reports that output is not an interactive terminal

#### Scenario: NO_COLOR set
- **WHEN** the `NO_COLOR` environment variable is set
- **THEN** the system does not emit color sequences

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

### Requirement: The terminal contract is frozen and extended by capabilities
The system SHALL treat the methods of the `Terminal` type (acquire, release, size, next event, write) as the complete required contract for a terminal, and SHALL describe any further ability, such as reporting the cursor position, as a separate optional capability type.

#### Scenario: Minimal terminal
- **WHEN** an application supplies a terminal that implements only the required methods
- **THEN** it can be run interactively, and abilities that need an optional capability are skipped

### Requirement: Environment probing helpers are not part of the supported API
The system SHALL expose environment detection through `detectEnvironment`, the `Environment` record, the mode selection and a function that builds an `Environment` from variables (for tests), and SHALL NOT expose the helpers that gather its inputs from the process (probing the standard streams, parsing the probe output, recognising a terminal path) as public API.

#### Scenario: Detecting the environment
- **WHEN** an application calls the environment detection
- **THEN** it receives an `Environment`, and a test can build one from variables without touching the process

### Requirement: Waiting for input checks less often when idle
The Unix terminal SHALL lengthen the time between its checks for input while no input arrives, up to a ceiling given when the terminal is created (default 0.5 seconds), and SHALL return to its shortest interval as soon as input arrives. A ceiling at or below the shortest interval SHALL turn the backoff off. The backoff SHALL NOT delay the timeouts the terminal depends on (the wait for a lone Escape key to be told from the start of a sequence, and the wait for a cursor position report).

#### Scenario: Idle terminal
- **WHEN** no input has arrived for longer than the time it takes the backoff to reach its ceiling
- **THEN** the terminal checks for input no more often than the ceiling allows

#### Scenario: Input after a pause
- **WHEN** a key is pressed while the terminal is checking at a long interval
- **THEN** the key is delivered as an event after at most that interval, and the terminal goes back to its shortest interval

#### Scenario: Escape key
- **WHEN** the Escape key is pressed while the terminal is idle at its ceiling
- **THEN** it is still delivered as an Escape key, not mistaken for the start of an escape sequence

#### Scenario: Cursor position request
- **WHEN** the terminal is asked for the cursor position while its input check is idle at its ceiling
- **THEN** the reply is still read and the request is answered within its own timeout, because the request reads the reply itself and does not wait for the idle check to wake
