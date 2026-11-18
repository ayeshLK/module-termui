# Spec Delta

## Purpose

Defines how an application built with the toolkit behaves when it is not attached to a full interactive terminal, such as when piped, redirected, or run in CI, so the same program works safely in scripts.

## ADDED Requirements

### Requirement: Mode selection from the environment
The system SHALL choose interactive, piped-output, piped-input, or fully headless operation based on whether standard input and standard output are terminals.

#### Scenario: Fully interactive
- **WHEN** both stdin and stdout are terminals
- **THEN** the application runs with the inline interactive interface

#### Scenario: Fully headless
- **WHEN** neither stdin nor stdout is a terminal
- **THEN** the application runs with plain output and no interactive input

### Requirement: Data on stdout, interface elsewhere
When stdout is redirected but a terminal is available, the system SHALL draw the interactive interface to the terminal (or stderr) and write only the application's result output to stdout.

#### Scenario: Piped result
- **WHEN** an interactive application runs with stdout piped to another program
- **THEN** the piped program receives only result output and no cursor-control or spinner sequences

### Requirement: Prompts without a terminal
When no terminal is available to answer a prompt, the system SHALL return a `NoTerminal` error, or the caller-supplied default if one was provided, and SHALL NOT block waiting for input.

#### Scenario: No default supplied
- **WHEN** a confirm prompt is shown with no terminal and no default
- **THEN** the call returns a `NoTerminal` error immediately

#### Scenario: Default supplied
- **WHEN** a confirm prompt with a default of "no" is shown with no terminal
- **THEN** the call returns "no" without waiting

### Requirement: Predictable plain output
In headless operation the system SHALL produce deterministic plain-text output with no color, cursor movement, or animation, using a default width of 80 columns when none can be determined.

#### Scenario: Width unknown
- **WHEN** wrapped text is rendered and the terminal width cannot be determined
- **THEN** text is wrapped at 80 columns

#### Scenario: Repeated runs
- **WHEN** the same application runs twice headless with the same inputs
- **THEN** the output is byte-for-byte identical
