## ADDED Requirements

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
