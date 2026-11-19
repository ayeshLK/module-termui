## ADDED Requirements

### Requirement: An idle loop checks less often
The system SHALL lengthen the time between the loop's checks for messages while nothing arrives, up to the ceiling `maxPollInterval` (default 0.5 seconds), and SHALL return to the shortest interval, `pollInterval`, as soon as something other than a timer tick is handled. The ceiling SHALL be reached only after sustained idleness, and a ceiling at or below `pollInterval` SHALL turn the backoff off.

#### Scenario: Idle for a long time
- **WHEN** a program has handled no message for longer than the time it takes the backoff to reach its ceiling
- **THEN** the loop checks for messages no more often than the ceiling allows

#### Scenario: A message ends the backoff
- **WHEN** a message that is not a timer tick arrives while the loop is checking at a long interval
- **THEN** the message is handled after at most that interval, and the loop goes back to the shortest interval


#### Scenario: Backoff turned off
- **WHEN** the program is run with `maxPollInterval` equal to or below `pollInterval`
- **THEN** the loop checks at the `pollInterval` interval at all times, as before

#### Scenario: Nothing is lost
- **WHEN** messages arrive while the loop is checking at a long interval
- **THEN** every message is delivered, in the order it was received, and none is dropped

### Requirement: The poll interval is the shortest sleep
The system SHALL treat `pollInterval` as the shortest time the loop sleeps when there is nothing to do, and MAY sleep longer when the program has been idle.

#### Scenario: Active program
- **WHEN** messages keep arriving more often than the shortest interval
- **THEN** the loop checks at the shortest interval

### Requirement: Timers do not keep the loop awake or get delayed by it
The system SHALL NOT treat a tick of a timer started with the `every` command as activity that ends the backoff, and SHALL lower the ceiling to half the period of the program's fastest timer, so ticks are handled on time.

#### Scenario: A timer does not keep the loop at full speed
- **WHEN** a program has a timer of 100 ms and nothing else happens
- **THEN** the loop still backs off, to at most 50 ms, and each tick is handled within that time of its due time

#### Scenario: A timer is not delayed by the ceiling
- **WHEN** a program has a timer of 100 ms and the ceiling is 500 ms
- **THEN** the loop never sleeps longer than 50 ms

### Requirement: A timer tick that changes nothing draws nothing
The system SHALL NOT ask the renderer to draw when the only thing handled since the last frame was ticks of the program's timers and the program's view is the same as the last frame it drew.

#### Scenario: A quiet tick
- **WHEN** a timer ticks and the program's view is unchanged
- **THEN** the renderer is not asked to draw

#### Scenario: A tick that changes the view
- **WHEN** a timer ticks and the program's view changes
- **THEN** the new frame is drawn

