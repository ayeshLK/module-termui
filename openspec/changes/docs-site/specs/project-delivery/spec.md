# Spec Delta

## ADDED Requirements

### Requirement: The documentation site is built on pull requests
A pull request that changes the site or the examples it includes SHALL build the site, and a build failure SHALL be reported as a failed check. A pull request that changes neither SHALL NOT run the site build.

#### Scenario: A page breaks the build
- **WHEN** a pull request changes a site page so that the site fails to build
- **THEN** the pull request shows a failed check

#### Scenario: An unrelated pull request
- **WHEN** a pull request changes only package code
- **THEN** the site build does not run

### Requirement: The documentation site is published from the main branch
The site SHALL be published to GitHub Pages automatically after a change to the site or its included examples reaches the main branch, and publishing SHALL NOT require a package release.

#### Scenario: A page is edited
- **WHEN** a change to a site page is merged to the main branch
- **THEN** the published site shows the change without a new package version

### Requirement: Included examples are compiled in continuous integration
Every example program that a site page includes SHALL be compiled by the continuous-integration build against the latest published package, on at least one supported platform.

#### Scenario: Example pinned to a release
- **WHEN** the build runs
- **THEN** each included example is resolved against a published package version and compiled
