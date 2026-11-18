# Spec Delta

## Purpose

Defines the application runtime: a single loop that turns input, effect results, and timers into messages, applies them to the application's model, and redraws, so that long-running work can proceed without blocking the interface.

## ADDED Requirements

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
