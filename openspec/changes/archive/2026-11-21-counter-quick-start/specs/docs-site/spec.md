# Spec Delta

## MODIFIED Requirements

### Requirement: A tutorial section builds a small harness step by step
The site SHALL include a tutorial section with a track that builds a small agent harness in ordered steps, each step being a complete program that compiles and runs.

#### Scenario: The tutorial is in the site
- **WHEN** a reader opens the site's sidebar
- **THEN** a tutorials section is listed, it contains the harness track, and that track's first step is a complete counter program

#### Scenario: Steps are ordered
- **WHEN** a reader finishes one tutorial step
- **THEN** the page links to the next step, and the next step's program extends the previous one

## REMOVED Requirements

### Requirement: A quick start builds and runs a small program
**Reason**: This requirement described the to-do program, which keeps its data between runs. The to-do list becomes a tutorial; the Quick start is now a smaller first program.
**Migration**: The to-do behaviour is carried by "A to-do tutorial builds a fuller application"; the Quick start by "The quick start runs a counter in about five minutes".

### Requirement: The quick-start program is compiled and tested
**Reason**: It named the to-do program's tests as the quick start's tests.
**Migration**: "The quick-start program is compiled and verified" covers the Quick start's program, and "A to-do tutorial builds a fuller application" covers the to-do program's tests.

## ADDED Requirements

### Requirement: The quick start runs a counter in about five minutes
The site SHALL open its "Start here" section with a quick-start page that takes a reader from an empty folder to a running program in about five minutes. The program SHALL be the smallest one that shows the whole shape of an application: state, handling a message, describing the screen and running.

#### Scenario: A reader opens the first page
- **WHEN** a reader opens the first page of the "Start here" section
- **THEN** it is the quick start, and it contains the requirements, the staged program, the command that runs it and a recording of the result

#### Scenario: The program is built in stages
- **WHEN** a reader applies the page's stages in order and builds after any of them
- **THEN** the program compiles, and it needs no credentials or network access beyond fetching the library

#### Scenario: The page explains the program
- **WHEN** a reader finishes running the program
- **THEN** the page says in a few sentences what the update function, the view function and running the program each do

#### Scenario: The page leads on
- **WHEN** a reader finishes the quick start
- **THEN** the page links to the concept that explains the program's shape, to the tutorials, and to the to-do list as a fuller first application

### Requirement: The quick-start program is compiled and verified
The quick-start page SHALL include its complete program from a source file under `examples/`, and the project's continuous integration SHALL build it against the library in the repository and exercise it with scripted input, so the page cannot show a program that does not build or does not behave as described.

#### Scenario: The quick-start program no longer compiles
- **WHEN** a change makes the quick-start example fail to compile
- **THEN** the continuous-integration build fails

#### Scenario: Its behaviour changes
- **WHEN** a change makes the program stop counting up, counting down or quitting as the page describes
- **THEN** the scripted check of the example fails in continuous integration

### Requirement: Tutorials are offered as two tracks
The site SHALL list a "Tutorials" section containing two tracks, a to-do list and an agent harness, and a tutorials page from which a reader chooses one. The homepage's primary action SHALL open the quick start and its second action SHALL open the tutorials page, so a first program and a fuller project are distinct paths.

#### Scenario: A reader looks for what to build next
- **WHEN** a reader opens the tutorials page
- **THEN** it describes both tracks in a sentence each and links to each

#### Scenario: The sidebar groups the tracks
- **WHEN** a reader opens the site's sidebar
- **THEN** the to-do list and the agent harness are listed as separate tracks under one tutorials section, and the quick start is not among them

### Requirement: A to-do tutorial builds a fuller application
The tutorials SHALL include a to-do list track that builds a program with a list the reader moves through, marks done, adds to and deletes from, that leaves the list in the terminal's scrollback on quitting and keeps its items in a file between runs. The program shown SHALL be included from a source file under `examples/` that the project's continuous integration builds and whose tests it runs, and the program SHALL NOT need credentials or network access.

#### Scenario: The program is used twice
- **WHEN** a reader runs the to-do program, adds an item, quits and runs it again
- **THEN** the item added in the first run is listed in the second

#### Scenario: Its behaviour changes
- **WHEN** a change makes the program stop adding, completing, deleting or saving items as the page describes
- **THEN** a test of the example fails in continuous integration

#### Scenario: The track leads on
- **WHEN** a reader finishes the to-do track
- **THEN** the page links to the concept that explains the program's shape and to the harness track

### Requirement: The harness tutorial continues from the quick start
The first step of the harness track SHALL state that its program is the one built in the quick start and SHALL show that program in full, so a reader who skipped the quick start can still continue from it. It SHALL NOT repeat the quick start's setup and staging.

#### Scenario: A reader who did the quick start
- **WHEN** a reader opens the first harness step after finishing the quick start
- **THEN** the page says the program is the one they already have and does not ask them to rebuild it

#### Scenario: A reader who skipped the quick start
- **WHEN** a reader opens the first harness step without having done the quick start
- **THEN** the page shows the whole program so they can start from it

### Requirement: Moved tutorial pages keep working addresses
When a tutorial page moves to a new address, the old address SHALL redirect to the new one, so links to the published pages keep working.

#### Scenario: An old tutorial address
- **WHEN** a reader opens an address that a harness tutorial page had before it moved
- **THEN** they arrive at that page at its new address
