## ADDED Requirements

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
