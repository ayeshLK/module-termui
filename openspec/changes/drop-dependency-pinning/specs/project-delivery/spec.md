# Spec Delta

## ADDED Requirements

### Requirement: Included examples resolve termui from Ballerina Central
Every example program that a site page includes SHALL be compiled by the continuous-integration build, on at least one supported platform, against the latest published termui, which the example's manifest does not name a version of.

#### Scenario: Example resolved from Ballerina Central
- **WHEN** the build runs
- **THEN** each included example resolves termui from Ballerina Central, with no version written in its manifest, and is compiled

#### Scenario: Example built against the working tree
- **WHEN** a contributor or the build runs the script that points the examples at the source
- **THEN** each example's manifest names the locally built termui from the local repository, and running the script again leaves one such entry and not two

## REMOVED Requirements

### Requirement: Included examples are compiled in continuous integration
**Reason**: Its only scenario describes the examples as pinned to a release. The examples no longer carry a version, so the requirement is replaced by "Included examples resolve termui from Ballerina Central", which keeps the same obligation to compile them in CI.
**Migration**: None. The replacement requirement covers the same examples and the same build.
