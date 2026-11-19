# project-delivery Specification

## Purpose
Defines how the `ayesha/termui` package is versioned, built, tested, checked for native-image compatibility, and released, so contributors and consumers can rely on a consistent and safe delivery path.

## Requirements

### Requirement: Single source of truth for the package version
The package version SHALL be defined in exactly one place, and every file that carries the version (package metadata and the in-code version constant) SHALL be generated from it.

#### Scenario: Version bump
- **WHEN** a maintainer changes the version in the single source
- **THEN** regenerating the build files updates the package metadata and the in-code version constant to the same value

#### Scenario: Development versions
- **WHEN** the source version carries a development suffix
- **THEN** the generated package metadata and in-code constant contain the version without that suffix

### Requirement: Pull requests are built and tested
Every pull request SHALL trigger a build and the default test suite on Linux and macOS, and a failing build or test SHALL be reported as a failed check.

#### Scenario: Pull request opened
- **WHEN** a pull request is opened or updated
- **THEN** the package is built and the default tests run on both Linux and macOS

#### Scenario: Superseded run
- **WHEN** a newer commit is pushed to the same pull request while a run is in progress
- **THEN** the older run is cancelled

### Requirement: Default tests need no terminal
The default test suite SHALL pass in an environment that has no controlling terminal.

#### Scenario: Headless CI runner
- **WHEN** the default tests run on a runner without a tty
- **THEN** all default tests pass without skipping silently or hanging

### Requirement: Terminal-dependent tests are opt-in
Tests that require a real pseudo-terminal SHALL belong to a separate `tty` group that is excluded from the default run and runs only when explicitly requested.

#### Scenario: Default run
- **WHEN** the build runs without selecting the `tty` group
- **THEN** no tty-group test executes

#### Scenario: Explicit tty run in CI
- **WHEN** the `tty` group is requested on a CI runner
- **THEN** the tty-group tests run against an allocated pseudo-terminal on Linux and macOS

### Requirement: Test coverage is reported
The main-branch and pull-request builds SHALL produce a coverage report and publish it to the configured coverage service.

#### Scenario: Main-branch build
- **WHEN** a build on the main branch finishes its tests
- **THEN** a coverage report is uploaded

### Requirement: Continuous check against the latest Ballerina
The package SHALL be built and tested daily against the latest released Ballerina distribution, in addition to the version pinned for development.

#### Scenario: Daily run
- **WHEN** the daily schedule fires
- **THEN** the package is built and tested with the latest Ballerina distribution and the result is visible to maintainers

### Requirement: Native-image compatibility is checked without blocking
A workflow SHALL run the package's tests under GraalVM native image on a schedule and on demand, SHALL allow a pull request to opt out with a label, and a failure SHALL NOT block pull request merging or a release while native-image remains a non-gating goal.

#### Scenario: Native tests pass
- **WHEN** the native-image check runs and the tests pass under GraalVM
- **THEN** the check reports success

#### Scenario: Native tests fail
- **WHEN** the native-image check runs and a test or the native build fails
- **THEN** the failure is reported to maintainers and the pull request or release is not blocked

#### Scenario: Opt-out label
- **WHEN** a pull request carries the skip label
- **THEN** the native-image check does not run for that pull request

### Requirement: Static analysis on pull requests
Pull requests SHALL be analyzed with Ballerina's static analysis tool, and its findings SHALL be visible in the check output.

#### Scenario: Pull request opened
- **WHEN** a pull request is opened or updated
- **THEN** the package is scanned and any findings appear in the check results

### Requirement: Releases are manual and reproducible
A release SHALL be started manually by a maintainer from the package's owning repository, SHALL build and test the package, and SHALL publish the release version (without a development suffix) to Ballerina Central, tag it, and create a GitHub release.

#### Scenario: Successful release
- **WHEN** a maintainer triggers the release workflow and the build and tests pass
- **THEN** the package is published to Ballerina Central at the release version, the repository is tagged with that version, and a GitHub release is created

#### Scenario: Failing tests
- **WHEN** the release workflow's build or tests fail
- **THEN** nothing is published and no tag or GitHub release is created

#### Scenario: Forked repository
- **WHEN** the release workflow is triggered from a repository not owned by the maintainer
- **THEN** the release does not run

### Requirement: Workflows use least-privilege secrets and pinned actions
Each workflow step SHALL receive only the secrets it needs, and third-party actions SHALL be pinned to a fixed version or commit.

#### Scenario: Build step
- **WHEN** a workflow step builds or tests the package
- **THEN** only the credentials required for that step are present in its environment, and no step exports the full set of repository secrets

### Requirement: Compatibility policy is published
The project SHALL publish a compatibility policy that states that versions follow semantic versioning, what counts as public API (the documented public symbols; symbols marked low-level are covered but may change in a minor release only with notice), how a deprecation is announced and for how long it is kept, and which Ballerina versions and platforms are supported.

#### Scenario: Reading the policy
- **WHEN** a user wants to know what a minor release may change
- **THEN** the policy, linked from the README, answers it

#### Scenario: Deprecation
- **WHEN** a public symbol is to be removed
- **THEN** it is first marked deprecated in a minor release and kept until the next major release, with the replacement named

### Requirement: Changes are recorded in a changelog
The project SHALL keep a changelog with one entry per release, listing added, changed, deprecated, removed and fixed items, and SHALL include a migration note for any release that removes or changes public API.

#### Scenario: A release with a removal
- **WHEN** a release removes a public symbol
- **THEN** its changelog entry names the symbol and what to use instead

### Requirement: A stable release is gated by a checklist
The project SHALL keep a checklist for a release marked stable, and SHALL NOT tag it until every item is done: the API audit is complete, the documentation and generated API documentation are current, the changelog has the release's entry, the status wording and badges no longer say experimental, the package version is the release version, and the terminal checks listed in the checklist have been run.

#### Scenario: Checklist incomplete
- **WHEN** an item of the checklist is not done
- **THEN** the release is not started

#### Scenario: Status wording
- **WHEN** the release is marked stable
- **THEN** the README, `Package.md` and badges describe the package as stable and the experimental notice is gone

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
