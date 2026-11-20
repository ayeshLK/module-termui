## MODIFIED Requirements

### Requirement: Concepts and best practices are documented
The site SHALL explain the toolkit's core concepts (the update and view loop, commands and timers, inline rendering, headless operation and the line editor) and SHALL include a best-practices section that covers strands and isolation, testing without a terminal, and the compatibility policy.

#### Scenario: A concept is looked up
- **WHEN** a reader opens the concepts section
- **THEN** each core concept listed above has its own page reachable from the sidebar

#### Scenario: The strand rule is stated
- **WHEN** a reader opens the best-practices section
- **THEN** a page states that a blocking call in a non-isolated function stalls other work, and shows how to avoid it

## ADDED Requirements

### Requirement: Consumer documentation does not describe runtime internals
The documentation site and the README SHALL describe what a program built with the toolkit can write and rely on, and SHALL NOT describe how the runtime achieves it internally. In particular they SHALL NOT include polling or backoff mechanics, measured latency or CPU figures, benchmark scripts, or the algorithm the renderer uses to place the live region. Such behavior is specified in the capability specs, which are the reference for people working on the toolkit itself.

#### Scenario: A reader looks for idle behavior
- **WHEN** a reader browses the site's sidebar and the README
- **THEN** no page or section is devoted to idle cost, and no page quotes CPU or first-key latency figures

#### Scenario: Guidance survives without the mechanism
- **WHEN** a page advises on timers or animation
- **THEN** it gives the practical rule (an unchanged view causes no redraw, keep `view` cheap) without explaining the runtime's wake-up behavior
