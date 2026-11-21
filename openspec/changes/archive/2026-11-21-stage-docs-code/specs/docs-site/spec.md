# Spec Delta

## MODIFIED Requirements

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

## ADDED Requirements

### Requirement: Stages introduce only what they use
Each stage of a build-along page SHALL add only the imports it uses and SHALL NOT call anything that a later stage defines, so that no stage leaves an unused import or an undefined name.

#### Scenario: A stage uses a helper
- **WHEN** a stage's code calls a function or type
- **THEN** that function or type is defined in that stage or an earlier one

#### Scenario: A stage adds an import
- **WHEN** a stage adds an import
- **THEN** that stage's code uses the imported module
