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
