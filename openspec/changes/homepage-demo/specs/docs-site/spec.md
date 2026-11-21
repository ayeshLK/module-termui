# Spec Delta

## MODIFIED Requirements

### Requirement: The site works without scripts for reading
Every page's explanatory text and code SHALL be readable with scripts disabled; interactive components MAY be absent in that case. A recording that a page presents as an example of the library's behaviour SHALL have a text description of what it shows, visible when scripts are disabled, in addition to the page reporting that the recording needs scripts.

#### Scenario: Scripts disabled
- **WHEN** a page is opened with scripts disabled
- **THEN** the text and code samples are visible and the page reports that the interactive component needs scripts

#### Scenario: A recording with scripts disabled
- **GIVEN** a page that embeds a recording with a text description
- **WHEN** the page is opened with scripts disabled
- **THEN** the description is visible, and it tells the reader what happens in the recording in the order it happens

## ADDED Requirements

### Requirement: The homepage plays a recording of a runnable example
The documentation homepage SHALL embed a recording of a runnable example program from `examples/`, which starts playing on its own unless the reader has asked their system to reduce motion, and SHALL link to the example's source. The recording SHALL show streamed output, the live region, committed output and an approval prompt, and on screens wide enough for two columns it SHALL be shown beside the introductory text, so that it is on the first screen.

#### Scenario: A first-time visitor opens the homepage
- **WHEN** a visitor opens the homepage with scripts enabled
- **THEN** a recording of a real program plays without navigating elsewhere, and the page links to that program's source

#### Scenario: A wide screen
- **WHEN** a visitor opens the homepage on a screen wide enough for two columns
- **THEN** the recording is beside the introductory text and visible without scrolling

#### Scenario: A visitor prefers reduced motion
- **GIVEN** a visitor whose system asks for reduced motion
- **WHEN** they open the homepage
- **THEN** the recording does not start by itself, and the frame it shows before playing has streamed output, committed output and an approval prompt on screen

#### Scenario: The recording is of a real example
- **WHEN** the homepage links to the recorded program
- **THEN** the link leads to a program under `examples/` that the project's continuous integration builds

### Requirement: The homepage states the library's general scope
The homepage SHALL describe the library as a general-purpose terminal UI library and SHALL present the agent harness as one example of what it can build, not as the library's purpose.

#### Scenario: The homepage describes the library
- **WHEN** a visitor reads the homepage's description and tagline
- **THEN** they describe a general-purpose terminal UI library and do not say or imply that it is only for AI agents
