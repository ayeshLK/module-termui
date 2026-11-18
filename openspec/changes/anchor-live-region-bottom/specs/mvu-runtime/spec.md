# Spec Delta

## ADDED Requirements

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
