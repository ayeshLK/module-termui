## ADDED Requirements

### Requirement: The renderer contract is frozen and extended by capabilities
The system SHALL treat the methods of the `Renderer` type (draw, commit prose, commit block, resize, close) as the complete required contract for a renderer, and SHALL offer any further ability, now or later, as a separate optional capability type that a renderer may also implement.

#### Scenario: Minimal renderer
- **WHEN** an application passes a renderer that implements only the required methods to the runtime
- **THEN** the program runs, drawing and committing through those methods

#### Scenario: Optional ability
- **WHEN** a renderer implements an optional capability
- **THEN** the runtime uses it, and a renderer that does not implement it is not affected

### Requirement: Cell buffer is the supported way to inspect a frame
The system SHALL document the cell buffer and its inspection functions as the supported way to examine a rendered frame, including each cell's style, and SHALL keep them public for that purpose.

#### Scenario: Inspecting a frame in a test
- **WHEN** a test builds a buffer from styled lines
- **THEN** it can read the text of each row and the character and style of each cell
