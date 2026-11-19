## ADDED Requirements

### Requirement: A quick start builds and runs a small program
The site SHALL open its "Start here" section with a quick-start page. The page SHALL take a reader from an empty folder to a running program: it SHALL state the requirements, show how to create a package and import the library, show the program, show how to run it, and show a recording of it working. The program SHALL be small, complete and useful on its own, SHALL keep its data between runs, and SHALL NOT need credentials or network access.

#### Scenario: A reader opens the first page
- **WHEN** a reader opens the first page of the "Start here" section
- **THEN** it is the quick start, and it contains the import, the program, the command that runs it and a recording of the result

#### Scenario: The program is used twice
- **WHEN** a reader runs the quick-start program, adds an item, quits and runs it again
- **THEN** the item added in the first run is listed in the second

#### Scenario: The page leads on
- **WHEN** a reader finishes the quick start
- **THEN** the page links to the concept that explains the program's shape and to the tutorial

### Requirement: The quick-start program is compiled and tested
The program shown on the quick-start page SHALL be included from a source file under `examples/`, and the project's continuous integration SHALL compile it and run its tests, so the page cannot show a program that does not build or does not behave as described.

#### Scenario: The quick-start program no longer compiles
- **WHEN** a change makes the quick-start example fail to compile
- **THEN** the continuous-integration build fails

#### Scenario: Its behaviour changes
- **WHEN** a change makes the program stop adding, completing, deleting or saving items as the page describes
- **THEN** a test of the example fails in continuous integration

### Requirement: The modules are listed after the quick start
The site SHALL describe the package's modules, and what each is for, on a page in the "Start here" section that follows the quick start, and SHALL link to the API reference from it.

#### Scenario: A reader looks for the modules
- **WHEN** a reader opens the "Start here" section
- **THEN** a page lists each of the package's modules with a one-line purpose and a link to the API reference
