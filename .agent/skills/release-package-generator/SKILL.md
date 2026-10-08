---
name: release-package-generator
description: Compile release order, rollback steps, configuration changes, monitoring points, and risk summaries into a structured release record. Use when Codex needs to prepare `release-note` style output after verification and acceptance are complete, but before human approval and actual deployment.
---

# Release Package Generator

## Overview

Prepare a structured release record and rollback checklist for human review and deployment preparation.

## Execution steps

1. Read `verification/result.md`, `acceptance.md`, `impact.yaml`, and `standards/global/release-gates.md`.
2. Summarize affected repositories, branches, configurations, data changes, release order, and rollback steps.
3. Specify post-release monitoring points and summarize risks.
4. If acceptance, rollback instructions, or verification are missing, explicitly state that no release conclusion can be issued.

## Output requirements

- Update the release record template by default
- Prepare the release without directly authorizing deployment
- Explicitly document rollback steps and monitoring points
- Do not skip release gates

## Validation checklist

- Are affected repositories and their release order listed?
- Are database and configuration changes documented?
- Are rollback steps documented?
- Are post-release monitoring points documented?
