# Spec Delta

## ADDED Requirements

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
