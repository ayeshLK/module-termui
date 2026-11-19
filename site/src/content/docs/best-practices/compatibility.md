---
title: Compatibility and upgrades
description: "What you can rely on across termui versions."
sidebar:
  order: 3
---

termui follows [semantic versioning](https://semver.org). The full policy is in
[`COMPATIBILITY.md`](https://github.com/ayeshLK/module-termui/blob/main/COMPATIBILITY.md); this page
is the short version for application authors.

## What this means for your code

- **Ballerina records the version for you.** The first build writes it to `Dependencies.toml`, newer patch
  releases are picked up automatically, and a newer minor release is your choice. A patch or minor release
  does not break code that uses the documented API and follows the two rules below.
- **Handle the messages and commands you know and ignore the rest.** New messages and commands arrive in
  minor releases, so an `update` that returns `()` for a message it does not recognise keeps working.
- **Implementing `Terminal` or `Renderer` yourself is safe.** Their required methods are fixed. New
  abilities arrive as separate optional types, such as `CursorReporter`, that your implementation may
  also provide.
- **Defaults are frozen for a major version.** Colors and reflow on, bottom anchoring off, interactive on,
  `pollInterval` 5 ms and `maxPollInterval` 0.5 s stay as they are until termui 2.0.
- **Symbols marked low-level** are covered, but may change in a minor release, with notice.

## Where to check before you upgrade

- The [changelog](https://github.com/ayeshLK/module-termui/blob/main/CHANGELOG.md) lists every change
  per release, with migration notes.
- Deprecations are announced in the changelog and kept for the period the policy states.
- The API reference for each version is on
  [Ballerina Central](https://central.ballerina.io/ayesha/termui/1.0.0).

Supported: macOS and Linux, and Ballerina 2201.14. Windows is not supported.
