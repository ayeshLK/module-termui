# docs-site Specification

## Purpose
Defines the public documentation site for the toolkit: what it teaches, how its code samples are kept correct, and how readers reach it, so people can learn the library's concepts and build a first program without reading the source.

## Requirements

### Requirement: The site is published and reachable
The project SHALL publish a documentation site at a stable public address, and the README and the package overview SHALL link to it.

#### Scenario: Reader follows the README
- **WHEN** a reader opens the README of the repository
- **THEN** it contains a link to the documentation site that resolves to the site's home page

### Requirement: Concepts and best practices are documented
The site SHALL explain the toolkit's core concepts (the update and view loop, commands and timers, inline rendering, headless operation, the line editor and idle cost) and SHALL include a best-practices section that covers strands and isolation, testing without a terminal, and the compatibility policy.

#### Scenario: A concept is looked up
- **WHEN** a reader opens the concepts section
- **THEN** each core concept listed above has its own page reachable from the sidebar

#### Scenario: The strand rule is stated
- **WHEN** a reader opens the best-practices section
- **THEN** a page states that a blocking call in a non-isolated function stalls other work, and shows how to avoid it

### Requirement: A tutorial section builds a small harness step by step
The site SHALL include a tutorial section that builds a small agent harness in ordered steps, each step being a complete program that compiles and runs.

#### Scenario: The tutorial is in the site
- **WHEN** a reader opens the site's sidebar
- **THEN** a tutorial section is listed, and its first step is a complete counter program

#### Scenario: Steps are ordered
- **WHEN** a reader finishes one tutorial step
- **THEN** the page links to the next step, and the next step's program extends the previous one

### Requirement: Code in pages comes from compiled programs
Every multi-line program shown in a tutorial page SHALL be included from a source file under `examples/`, and the project's continuous integration SHALL compile every such file, so a page cannot show code that does not build.

#### Scenario: An included program no longer compiles
- **WHEN** a change makes an included example fail to compile
- **THEN** the continuous-integration build fails

#### Scenario: A page shows a program
- **WHEN** a tutorial page displays a full program
- **THEN** the displayed text is the content of the example file, not a separate copy

### Requirement: Recordings come from the real library
Terminal recordings shown on the site SHALL be recorded from programs built with the toolkit, and each recording SHALL be playable with pause and seek, with its text selectable.

#### Scenario: A recording is played
- **WHEN** a reader opens a page with a recording
- **THEN** they can pause it, move to another point in it, and copy text from it

### Requirement: The update and view loop can be tried in the page
The site SHALL include an interactive component on the concepts page for the update and view loop in which the reader sends messages and sees the resulting state and frame. The component SHALL state that it is an illustration and link to the runnable example.

#### Scenario: The reader sends a message
- **WHEN** a reader triggers a message in the component
- **THEN** the displayed state and frame change as the loop would change them

### Requirement: The site works without scripts for reading
Every page's explanatory text and code SHALL be readable with scripts disabled; interactive components MAY be absent in that case.

#### Scenario: Scripts disabled
- **WHEN** a page is opened with scripts disabled
- **THEN** the text and code samples are visible and the page reports that the interactive component needs scripts

### Requirement: The API reference is linked, not copied
The site SHALL link to the API reference published on Ballerina Central for each module, and SHALL NOT duplicate symbol-level documentation.

#### Scenario: A page mentions a symbol
- **WHEN** a page refers to a public type or function
- **THEN** the reference is a link to the API reference or the text names the symbol without restating its documentation

### Requirement: The tutorial ends in a working harness
The tutorial SHALL consist of ordered steps that together build a small agent harness with a prompt, a streamed answer, a status line with interrupt, tool calls with approval, and tests. Every step listed in the tutorial index SHALL have a page, and no page SHALL link to a step that does not exist.

#### Scenario: Following the steps
- **WHEN** a reader completes the last step
- **THEN** they have a harness program with a prompt, a streamed answer, a status line, an approval prompt and a passing test, built from the earlier steps

#### Scenario: No placeholders
- **WHEN** a reader opens the tutorial index or any step
- **THEN** every step it lists or links to has a page

### Requirement: Tutorial programs need no credentials
Every tutorial program SHALL run without an account, an API key or a network connection, and the tutorial SHALL state how a real model would be connected in place of the scripted one.

#### Scenario: Running a step offline
- **WHEN** a reader runs any tutorial step on a machine with no network access
- **THEN** the program runs and behaves as the page describes

### Requirement: Each tutorial step's behaviour is checked
Continuous integration SHALL check each tutorial step's behaviour, not only that it compiles: a step that is interactive SHALL be exercised with scripted input and its output checked, and the testing step SHALL pass its own tests.

#### Scenario: A step stops behaving as described
- **WHEN** a change makes a tutorial step draw or commit different text from what its page shows
- **THEN** the continuous-integration build fails

### Requirement: Steps extend one another
Each tutorial step after the first SHALL start from the previous step's program and its page SHALL say what changed, so a reader can follow along by editing one file.

#### Scenario: A step's page lists its changes
- **WHEN** a reader opens step N (N greater than 1)
- **THEN** the page names what was added to the program from step N-1 and shows the new parts
