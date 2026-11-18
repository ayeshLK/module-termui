# text-primitives Specification

## Purpose
Defines the shared model for styled terminal text: how text is styled, how wide it is when displayed, and how it is wrapped, so that widgets and layout agree on measurements.

## Requirements

### Requirement: Styled text
The system SHALL represent text with optional foreground color, background color, and attributes (bold, dim, italic, underline, reverse), and SHALL support spans of different styles within a line.

#### Scenario: Mixed styles in a line
- **WHEN** a line contains a bold span followed by a plain span
- **THEN** the rendered output applies bold only to the first span

#### Scenario: Colors disabled
- **WHEN** color output is disabled for the environment
- **THEN** styled text renders without color sequences while keeping its characters intact

### Requirement: Display width
The system SHALL measure text by its displayed terminal width: wide characters (such as CJK) count as two columns, combining marks count as zero, and control or escape sequences count as zero.

#### Scenario: Wide characters
- **WHEN** the width of a string containing CJK characters is measured
- **THEN** each wide character contributes two columns

#### Scenario: Escape sequences
- **WHEN** the width of a string containing ANSI style sequences is measured
- **THEN** the sequences contribute zero columns

### Requirement: Wrapping
The system SHALL wrap text to a given column width at word boundaries, breaking inside a word only when the word alone exceeds the width, and SHALL preserve styles across the break.

#### Scenario: Word wrap
- **WHEN** a paragraph is wrapped to 20 columns
- **THEN** no wrapped line exceeds 20 columns and breaks occur at spaces where possible

#### Scenario: Overlong word
- **WHEN** a single word is wider than the wrap width
- **THEN** it is split across lines at the width limit

#### Scenario: Style continuity
- **WHEN** a styled span is split across two lines by wrapping
- **THEN** both resulting lines render the span with the same style

#### Scenario: Hanging indent
- **WHEN** a list item is wrapped with a hanging indent
- **THEN** continuation lines are indented to align under the item's text
