# Spec Delta

## Purpose

Defines how an application acquires and releases an interactive terminal, reads decoded input events from it, and writes output to it, including an in-memory terminal for tests and non-interactive use.

## ADDED Requirements

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
