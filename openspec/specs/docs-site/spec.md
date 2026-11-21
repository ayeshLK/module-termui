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
The site SHALL explain the toolkit's core concepts (the update and view loop, commands and timers, inline rendering, headless operation and the line editor) and SHALL include a best-practices section that covers strands and isolation, testing without a terminal, and the compatibility policy.

#### Scenario: A concept is looked up
- **WHEN** a reader opens the concepts section
- **THEN** each core concept listed above has its own page reachable from the sidebar

#### Scenario: The strand rule is stated
- **WHEN** a reader opens the best-practices section
- **THEN** a page states that a blocking call in a non-isolated function stalls other work, and shows how to avoid it

### Requirement: A tutorial section builds a small harness step by step
The site SHALL include a tutorial section with a track that builds a small agent harness in ordered steps, each step being a complete program that compiles and runs.

#### Scenario: The tutorial is in the site
- **WHEN** a reader opens the site's sidebar
- **THEN** a tutorials section is listed, it contains the harness track, and that track's first step is a complete counter program

#### Scenario: Steps are ordered
- **WHEN** a reader finishes one tutorial step
- **THEN** the page links to the next step, and the next step's program extends the previous one

### Requirement: Code in pages comes from compiled programs
The complete program on every build-along page (the quick start and each tutorial step) SHALL be included from a source file under `examples/` that the project's continuous integration compiles. Any other multi-line program shown in a tutorial page SHALL likewise be included from a compiled source file. A build-along page MAY build its program up in stages from snippets written in the page, and the stages SHALL add up to the included program, with the program compiling after each stage.

#### Scenario: An included program no longer compiles
- **WHEN** a change makes an included example fail to compile
- **THEN** the continuous-integration build fails

#### Scenario: A page shows a program
- **WHEN** a build-along page displays the complete program
- **THEN** the displayed text is the content of the example file, not a separate copy

#### Scenario: A reader follows the stages
- **GIVEN** a reader who applies a build-along page's stages in order, starting from the page's first stage
- **WHEN** they build the program after any stage
- **THEN** it compiles, and after the last stage it is the program the page includes from the example file

#### Scenario: A stage names how it applies
- **WHEN** a stage's snippet is shown
- **THEN** the page says whether it replaces code the reader already has or is added to it, and where

### Requirement: Recordings come from the real library
Terminal recordings shown on the site SHALL be recorded from programs built with the toolkit, and each recording SHALL be playable with pause and seek, with its text selectable.

#### Scenario: A recording is played
- **WHEN** a reader opens a page with a recording
- **THEN** they can pause it, move to another point in it, and copy text from it

### Requirement: The update and view loop can be tried in the page
The site SHALL include an interactive component on the concepts page for the update and view loop in which the reader sends messages, steps a message through the loop one step at a time, selects any step to see what it does and, for the steps that are the reader's own code, the code that implements it, and sees the resulting state and frame. The component SHALL state that it is an illustration and link to the runnable example.

#### Scenario: The reader sends a message
- **WHEN** a reader triggers a message in the component
- **THEN** the displayed state and frame change as the loop would change them

#### Scenario: Stepping a message through the loop
- **WHEN** a reader sends a message and steps through it
- **THEN** each step of the loop is highlighted in the order a message takes through it, the state changes at the step where update runs, and the frame changes at the last step

#### Scenario: Inspecting a step
- **WHEN** a reader selects a step of the loop
- **THEN** the component shows what the step does, and for update and view it shows the code from the compiled counter example

#### Scenario: Using only the keyboard
- **WHEN** a reader uses only the keyboard
- **THEN** the controls for sending a message, stepping, and selecting a step are all reachable and operable, and the current step is announced to assistive technology

#### Scenario: Reduced motion
- **WHEN** the reader's system asks for reduced motion
- **THEN** nothing in the component moves and it does not play through on its own

#### Scenario: Scripts disabled
- **WHEN** the page is opened with scripts disabled
- **THEN** a written breakdown of every step of the loop, with the same explanations and the same code, is visible

### Requirement: The site works without scripts for reading
Every page's explanatory text and code SHALL be readable with scripts disabled; interactive components MAY be absent in that case. A recording that a page presents as an example of the library's behaviour SHALL have a text description of what it shows, visible when scripts are disabled, in addition to the page reporting that the recording needs scripts.

#### Scenario: Scripts disabled
- **WHEN** a page is opened with scripts disabled
- **THEN** the text and code samples are visible and the page reports that the interactive component needs scripts

#### Scenario: A recording with scripts disabled
- **GIVEN** a page that embeds a recording with a text description
- **WHEN** the page is opened with scripts disabled
- **THEN** the description is visible, and it tells the reader what happens in the recording in the order it happens

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

### Requirement: The modules are listed after the quick start
The site SHALL describe the package's modules, and what each is for, on a page in the "Start here" section that follows the quick start, and SHALL link to the API reference from it.

#### Scenario: A reader looks for the modules
- **WHEN** a reader opens the "Start here" section
- **THEN** a page lists each of the package's modules with a one-line purpose and a link to the API reference

### Requirement: Consumer documentation does not describe runtime internals
The documentation site and the README SHALL describe what a program built with the toolkit can write and rely on, and SHALL NOT describe how the runtime achieves it internally. In particular they SHALL NOT include polling or backoff mechanics, measured latency or CPU figures, benchmark scripts, or the algorithm the renderer uses to place the live region. Such behavior is specified in the capability specs, which are the reference for people working on the toolkit itself.

#### Scenario: A reader looks for idle behavior
- **WHEN** a reader browses the site's sidebar and the README
- **THEN** no page or section is devoted to idle cost, and no page quotes CPU or first-key latency figures

#### Scenario: Guidance survives without the mechanism
- **WHEN** a page advises on timers or animation
- **THEN** it gives the practical rule (an unchanged view causes no redraw, keep `view` cheap) without explaining the runtime's wake-up behavior

### Requirement: Stages introduce only what they use
Each stage of a build-along page SHALL add only the imports it uses and SHALL NOT call anything that a later stage defines, so that no stage leaves an unused import or an undefined name.

#### Scenario: A stage uses a helper
- **WHEN** a stage's code calls a function or type
- **THEN** that function or type is defined in that stage or an earlier one

#### Scenario: A stage adds an import
- **WHEN** a stage adds an import
- **THEN** that stage's code uses the imported module

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
