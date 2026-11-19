# Tasks

## 1. Policy and changelog

- [x] 1.1 Write `COMPATIBILITY.md` (semantic versioning, what is public API and the low-level carve-out, deprecation rule with `@deprecated`, supported Ballerina and platforms) and link it from the README and `CONTRIBUTING.md`; verify the links resolve and the policy answers each scenario in the delta spec
- [x] 1.2 Create `CHANGELOG.md` from the git history and release notes of 0.1.0 and 0.2.0 (Keep a Changelog layout), and add an "Unreleased" section; verify each past version matches its GitHub release
- [x] 1.3 After `api-audit-v1` is finished, add its removals and migration note to the changelog; verify every symbol removed in that change is named

## 2. Release checklist

- [x] 2.1 Add the stable-release checklist to `CONTRIBUTING.md` beside the release steps (API audit, line editor, docs and `bal doc` output, changelog entry, status wording, version, terminal checks); verify it lists each item from the delta spec
- [x] 2.2 Run the terminal checks from the checklist by hand (tmux and one Linux terminal: the harness with `anchorBottom`, a resize, an approval prompt) and note the results in the checklist or the release PR; verify any failure is either fixed or recorded as a known limit in the README

## 3. Status and repository

- [x] 3.1 Update the README and `Package.md`: remove the experimental notice and badge, state the platforms, remove "Not there yet" items that are done and keep the rest as the roadmap; verify no page still says experimental or 0.x
- [ ] 3.2 Enable GitHub Discussions, label a few `good first issue` items, and check `SECURITY.md` or an equivalent note exists; verify in the repository settings
- [x] 3.3 Do a final pass on the generated API docs (`bal doc`) and the Ballerina Central page preview; verify no undocumented public symbol and no broken links

## Workflow follow-up

- The user bumps the version to 1.0.0, runs the release workflow and announces it (update `docs/announcement-drafts.md` first).
- Archive the three v1 changes after the release is verified.
