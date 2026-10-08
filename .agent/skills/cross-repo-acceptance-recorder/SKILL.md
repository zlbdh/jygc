---
name: cross-repo-acceptance-recorder
description: Record cross-repository acceptance steps, actual results, anomalies, and remaining risks by business workflow, completing `acceptance.md` and `verification/result.md`. Use when Codex needs to capture acceptance evidence for a multi-repo change rather than relying on single-repo build results.
---

# Cross Repo Acceptance Recorder

## Overview

Document integration testing as structured acceptance evidence. Evaluate complete business workflows rather than individual repository results.

## Execution steps

1. Read `acceptance.md`, `impact.yaml`, `design.md`, and `verification/result.md`.
2. Record actions, expected results, actual results, and anomalies step by step along the user workflow.
3. Prioritize approval flows, state synchronization, order flows, exports, idempotency, and other critical workflows.
4. Record remaining risks in `verification/result.md` rather than leaving them in conversation history.

## Output requirements

- Update `acceptance.md` first
- Also update `verification/result.md`
- Base conclusions only on evidence from actual execution
- Do not declare a cross-repository request complete because one repository passes

## Validation checklist

- Is evidence organized by business workflow?
- Are expected and actual results documented?
- Are remaining risks explicitly documented?
