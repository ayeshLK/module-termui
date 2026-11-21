# Spec Delta

## MODIFIED Requirements

### Requirement: A to-do tutorial builds a fuller application
The tutorials SHALL include a to-do list track of ordered steps that build a program with a list the reader moves through, marks done, adds to and deletes from, that leaves the list in the terminal's scrollback on quitting and keeps its items in a file between runs. Each step SHALL be a complete program that compiles and runs. The finished program SHALL be included from a source file under `examples/` that the project's continuous integration builds and whose tests it runs, and no step SHALL need credentials or network access.

#### Scenario: The program is used twice
- **WHEN** a reader runs the to-do program, adds an item, quits and runs it again
- **THEN** the item added in the first run is listed in the second

#### Scenario: Its behaviour changes
- **WHEN** a change makes the program stop adding, completing, deleting or saving items as the page describes
- **THEN** a test of the example fails in continuous integration

#### Scenario: The track leads on
- **WHEN** a reader finishes the to-do track
- **THEN** the page links to the concept that explains the program's shape and to the harness track

#### Scenario: Stopping partway
- **WHEN** a reader finishes any step and builds the program
- **THEN** it compiles and runs, and does what that step's page says

## ADDED Requirements

### Requirement: The to-do track continues from the quick start and lists every step
The first step of the to-do track SHALL start from the counter built in the quick start, and each later step SHALL start from the previous step's program and say what changed. The track's overview page SHALL list every step, and every step it lists SHALL have a page.

#### Scenario: A reader who did the quick start
- **WHEN** a reader opens the first to-do step after finishing the quick start
- **THEN** the page tells them how to turn the counter they have into the first step's program

#### Scenario: A step's page lists its changes
- **WHEN** a reader opens a to-do step after the first
- **THEN** the page names what was added to the previous step's program and shows the new parts

#### Scenario: No placeholders
- **WHEN** a reader opens the to-do overview or any step
- **THEN** every step it lists or links to has a page
