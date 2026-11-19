## ADDED Requirements

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
