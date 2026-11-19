## ADDED Requirements

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
