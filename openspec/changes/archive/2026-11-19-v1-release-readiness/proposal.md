# Proposal

## Why

Releasing 1.0 is a commitment, and the project does not yet say what it commits to: there is no versioning or deprecation policy, no changelog, the README still calls the package experimental, and the delivery spec covers builds and releases but not what a release must contain. Users deciding whether to depend on 1.0 need that written down.

## What Changes

- A compatibility policy: semantic versioning, what counts as public API, how deprecations are announced and for how long, supported Ballerina and platforms (macOS and Linux; Windows not supported).
- A CHANGELOG covering 0.1.0 onward, with a migration note for 0.2 users from `api-audit-v1`, kept up to date at each release.
- A 1.0 checklist that gates the tag: API audit done, line editor done, docs and generated API docs check out, terminal checks done (tmux and one Linux terminal, best effort), status badge and README "experimental" text updated, version bumped, release notes.
- Repository hygiene for a stable release: GitHub Discussions on, good-first-issue labels, security and contribution notes where missing.

## Capabilities

### New Capabilities

### Modified Capabilities
- `project-delivery`: requirements for the compatibility policy, the changelog and the release checklist.

## Impact

- New `CHANGELOG.md` and policy text (in `CONTRIBUTING.md` or a new doc), README and `Package.md` status wording, `CONTRIBUTING.md` release steps, repository settings (not files).
- Depends on `api-audit-v1` and `line-editor` being complete; the user performs the release itself.
