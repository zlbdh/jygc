---
name: change-intake
description: Turn unclear requests, bugs, rework, or incident fixes into standard change records for the example product control repository. Use when Codex needs to create or refine `changes/CHANGE_ID/brief.md`, extract business goal, user roles, success criteria, non-goals, risks, and background before cross-repo impact analysis begins.
---

# Change Intake

## Overview

Turn the original request into a `brief.md` that can proceed through the control-repository workflow, providing reliable input for `impact.yaml`, task cards, and release governance.

## Execution steps

1. Read `repos/repos.yaml`, `docs/harness-engineering.md`, `docs/workflow.md`, and the target `changes/<change-id>/`.
2. Identify business goals, user roles, success criteria, non-goals, risks, and relevant background.
3. Write actionable, verifiable success criteria rather than vague goals.
4. When information is missing, retain only the necessary `Needs confirmation` items. Do not invent business details.

## Output requirements

- Create or update only `brief.md`
- Use American English by default
- Success criteria must be testable
- Do not issue a release conclusion directly

## Validation checklist

- Are the request's goals clear?
- Are user roles specific?
- Are success criteria verifiable?
- Do non-goals prevent scope creep?
- Are risks explicitly documented?
