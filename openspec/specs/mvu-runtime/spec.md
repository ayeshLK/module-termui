# mvu-runtime Specification

## Purpose
Defines the application runtime: a single loop that turns input, effect results, and timers into messages, applies them to the application's model, and redraws, so that long-running work can proceed without blocking the interface.

## Requirements

### Requirement: Single-owner message loop
The system SHALL process messages on one loop that alone reads and mutates the application model, applying each message in the order it was received.

#### Scenario: Ordered processing
- **WHEN** a key event and an effect result arrive in that order
- **THEN** the application's update logic sees them in the same order

#### Scenario: Update changes the model
- **WHEN** a message is processed
- **THEN** the model reflects the result before the next message is processed

### Requirement: Messages from every source
The system SHALL deliver user input events, resize events, effect results, and timer ticks to the application as messages through one queue.

#### Scenario: Concurrent sources
- **WHEN** keystrokes and a streaming effect produce messages at the same time
- **THEN** all messages are delivered and none is dropped

### Requirement: Effects return messages
The system SHALL let the application start asynchronous work from an update, and the work's results SHALL reach the application only as messages.

#### Scenario: Effect completes
- **WHEN** an effect started by an update finishes with a result
- **THEN** the application receives the result as a message

#### Scenario: Effect streams results
- **WHEN** an effect produces many results over time
- **THEN** each result arrives as its own message while the interface stays responsive

### Requirement: Immutable cross-strand messages
Messages delivered from other strands SHALL be immutable, so that effects cannot change application state outside the loop.

#### Scenario: Mutable payload rejected
- **WHEN** an effect attempts to post a mutable value as a message
- **THEN** the build or the post is rejected rather than allowing shared mutation

### Requirement: Frame coalescing
The system SHALL apply all queued messages before drawing and SHALL draw at most one frame per loop iteration.

#### Scenario: Burst of tokens
- **WHEN** fifty messages arrive between two iterations of the loop
- **THEN** all fifty are applied and exactly one frame is drawn

### Requirement: Responsive input during work
The system SHALL keep accepting and queuing user input while effects are running.

#### Scenario: Typing during a long task
- **WHEN** the user types while a long-running effect is in progress
- **THEN** the keystrokes are delivered as messages without waiting for the effect

### Requirement: Clean shutdown
The system SHALL let the application end the loop, SHALL stop timers and effects it started, and SHALL release the terminal.

#### Scenario: Application quits
- **WHEN** the application requests to quit
- **THEN** the loop ends, the terminal is restored, and no further messages are delivered

### Requirement: Blocking prompts on top of the loop
The system SHALL provide convenience prompts (such as confirm and select) that block the caller and return the user's answer while the loop handles input and drawing.

#### Scenario: Confirm prompt answered
- **WHEN** an application asks a confirm prompt and the user answers
- **THEN** the call returns the answer and the live region is cleared of the prompt

### Requirement: Bottom anchoring is a run option
The system SHALL let the application ask for the live region to be anchored to the bottom of the terminal when it runs a program, SHALL leave it off by default, and SHALL pass the choice to the interactive renderer it creates.

#### Scenario: Default
- **WHEN** a program is run without the option
- **THEN** the live region is drawn as it always was, starting on the cursor's row

#### Scenario: Option on
- **WHEN** a program is run on an interactive terminal with the option on
- **THEN** the first frame of the program's view is on the last rows of the terminal

#### Scenario: Not an interactive terminal
- **WHEN** a program is run with the option on while output is plain, piped, or headless
- **THEN** its output is unchanged

### Requirement: The interactive renderer is sized from the terminal
The system SHALL size the interactive renderer it hands out from the terminal itself, SHALL use the environment's size (`COLUMNS` and `LINES`, or the defaults) only when the terminal cannot report a size, and SHALL treat a reported size that is not positive in both dimensions as not reported. Running a terminal directly, with no environment, SHALL fall back to 80 columns by 24 rows in the same cases.

#### Scenario: The terminal reports its size
- **WHEN** an interface hands out the interactive renderer for a terminal that reports its size and the environment holds different or default values
- **THEN** the renderer uses the terminal's size, so blocks wrap to the real width and the region anchors to the real last row

#### Scenario: The terminal reports no usable size
- **WHEN** the terminal cannot report a size or reports zero for a dimension (a pseudo-terminal nobody sized)
- **THEN** the environment's size is used, and the program draws its first frame instead of failing to start

#### Scenario: A terminal run directly
- **WHEN** a program is run directly on a terminal that reports no usable size
- **THEN** it is drawn as an 80 by 24 terminal

### Requirement: The public surface is intentional
The system SHALL make a symbol public only when it is part of the supported API or is needed across the package's modules, and SHALL document every public symbol. Symbols that are public only because another module needs them SHALL be described as low-level in their module's documentation.

#### Scenario: Internal helpers are not exported
- **WHEN** a symbol is used only inside the module that declares it
- **THEN** it is not public

#### Scenario: Every public symbol is documented
- **WHEN** the package's API documentation is generated
- **THEN** each public type, function, class and constant has a description

### Requirement: Growth is additive
The system SHALL add new abilities without breaking existing programs and implementations: new commands, messages, keys and events are added as new members that programs are not required to handle, and new abilities of the renderer and the terminal are added as separate optional capability types, never as new required methods of the existing types.

#### Scenario: Program ignores what it does not know
- **WHEN** a program handles only the messages and events it knows and ignores the rest
- **THEN** it keeps working when a later release adds new messages or events

#### Scenario: Implementation of the renderer or terminal
- **WHEN** an application supplies its own renderer or terminal that provides only the required methods
- **THEN** the runtime works with it and uses an optional ability only when the implementation declares it

### Requirement: Defaults of run settings are stable
The system SHALL keep the defaults of the run settings (`colors`, `reflow`, `anchorBottom`, `interactive`, `pollInterval`) for the whole major version: the live region is not anchored to the bottom unless asked, and the terminal is assumed to re-wrap text on resize unless told otherwise.

#### Scenario: Defaults without options
- **WHEN** a program is run with the default options
- **THEN** the live region is drawn in place without bottom anchoring and the terminal is assumed to reflow

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
