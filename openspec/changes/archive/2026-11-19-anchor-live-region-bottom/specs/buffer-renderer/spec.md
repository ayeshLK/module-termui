# Spec Delta

## ADDED Requirements

### Requirement: Bottom-anchored live region
When the application enables bottom anchoring and the terminal reports where its cursor is, the system SHALL place the live region on the last rows of the terminal on the first draw without changing any content above it. Anchoring SHALL be off by default.

#### Scenario: Room below the existing output
- **WHEN** the live region is first drawn with anchoring enabled and there are more free rows below the cursor than the region needs
- **THEN** the region occupies the last rows of the terminal, the blank rows between the output and the region are left empty, and no content moves

#### Scenario: Cursor near the bottom
- **WHEN** the live region is first drawn with anchoring enabled and the cursor is within the region's height of the bottom
- **THEN** the screen scrolls by only the number of rows the region lacks, and no existing content is overwritten

#### Scenario: Anchoring not requested
- **WHEN** the live region is drawn without enabling anchoring
- **THEN** it starts on the cursor's row, exactly as before

### Requirement: Blank rows are used before the screen scrolls
While there are blank rows between the output and an anchored live region, the system SHALL use them for committed output and for the region's growth before scrolling anything, and a shrinking region SHALL return its rows to them so the region keeps the last row.

#### Scenario: Commit fits in the blank rows
- **WHEN** the application commits fewer rows than there are blank rows above the region
- **THEN** the output appears directly below the existing content, the region does not move, and nothing scrolls

#### Scenario: Region grows
- **WHEN** an anchored region grows and there are blank rows above it
- **THEN** it grows upward into them, the rows already drawn at the bottom stay where they are, and nothing scrolls

#### Scenario: Region shrinks
- **WHEN** an anchored region shrinks
- **THEN** its last row stays on the last row of the terminal, the vacated rows become blank rows above it, and no blank row remains below it

#### Scenario: Commit longer than the blank rows
- **WHEN** the application commits more rows than there are blank rows
- **THEN** the blank rows are filled first, the rest of the output scrolls the screen normally, and no blank row is scrolled into the scrollback

#### Scenario: Wrapped prose
- **WHEN** the application commits a prose paragraph that the terminal wraps onto several rows
- **THEN** all of those rows count against the blank rows

### Requirement: Scrolling after the blank rows are used up
When no blank rows remain above an anchored live region, the system SHALL scroll output exactly as an unanchored region does, and everything that scrolls off the top, including content from before the session, SHALL remain in the terminal's scrollback.

#### Scenario: Blank rows exhausted
- **WHEN** committed output has filled every blank row and more output is committed
- **THEN** the screen scrolls one row per output row, the region stays on the last row, and the earlier output and banner can be reached in the scrollback

### Requirement: Anchoring depends on a known cursor position
Bottom anchoring SHALL have no effect unless the terminal reports its cursor position, and SHALL have no effect on the plain renderer, on output that is not an interactive terminal, or in full-screen mode.

#### Scenario: Terminal does not report its cursor
- **WHEN** anchoring is enabled and the terminal does not answer a cursor position request
- **THEN** the region is drawn exactly as it would be without anchoring

#### Scenario: Not an interactive terminal
- **WHEN** anchoring is enabled and output is plain, piped, or headless
- **THEN** output is identical to the output without anchoring

### Requirement: Re-anchoring after a resize
After a resize the system SHALL clear the old region as it does without anchoring, and SHALL anchor the region again at the next draw using the cursor position reported at that time.

#### Scenario: Window resized
- **WHEN** the terminal is resized and the application draws again
- **THEN** the region is on the last rows of the new size and no rows of the old region remain
