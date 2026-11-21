# Spec Delta

## ADDED Requirements

### Requirement: A troubleshooting guide is organized by symptom
The site SHALL include a troubleshooting page in the best-practices section whose entries are headed by the symptom a reader sees, and each entry SHALL give the likely cause, what to do or check next, and a link to the page that explains the behaviour in detail.

#### Scenario: A reader looks up a symptom
- **WHEN** a reader opens the troubleshooting page and scans its headings
- **THEN** each heading describes something the reader would observe, such as a program that hangs or output without colors, and not a component or an API name

#### Scenario: An entry sends the reader on
- **WHEN** a reader finishes an entry
- **THEN** it has told them why it happens and what to do, and links to the concept or reference page that explains the behaviour, without repeating that page

#### Scenario: Expected behaviour and bugs are told apart
- **WHEN** a symptom is how the toolkit is meant to behave, such as plain output in a pipe
- **THEN** the entry says so, and the page says what to include when something else looks like a bug

#### Scenario: The page is in the navigation
- **WHEN** a reader opens the site's sidebar
- **THEN** the troubleshooting page is listed in the best-practices section

### Requirement: Troubleshooting entries cover the execution modes and are backed by evidence
The troubleshooting guide SHALL cover running in CI and with redirected streams, questions without a terminal, color, resize and reflow, keys that do not behave as expected, effects and timers, and a terminal left in a bad state. Every claim in it SHALL be supported by a test, by the reference documentation, or by a reproduction recorded in the change that added it, and it SHALL NOT state platform support that the compatibility policy does not.

#### Scenario: Behaviour in CI is explained
- **WHEN** a reader whose program behaves differently in CI or a pipe opens the guide
- **THEN** entries explain plain output, the final-state-only live region, redirected output, and questions that return their defaults, as expected behaviour

#### Scenario: A claim has a source
- **WHEN** a maintainer checks an entry
- **THEN** the change that added the guide records, for that entry, the test, reference page or reproduction that supports it

#### Scenario: The guide does not describe internals
- **WHEN** a reader scans the guide
- **THEN** it contains no polling or backoff mechanics and no latency or CPU figures
