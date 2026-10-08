---
name: local-baseline-triage
description: Read local baseline, contract discovery, and workspace inspection reports to identify repository status, primary failures, and next actions. Use when Codex needs to interpret `reports/local-validation/*` outputs and produce concise repo-by-repo diagnosis before implementation or release decisions.
---

# Local Baseline Triage

## Overview

Summarize terminal output and reports into actionable conclusions, identifying which repositories can proceed and which need fixes first.

## Execution steps

1. Read the latest summary, matrix, and contracts reports under `reports/local-validation/`.
2. Report status, failures, priority, and next actions for each repository.
3. Distinguish pre-existing issues, environment issues, contract gaps, and actual code-quality problems first.
4. Highlight the first useful signal rather than copying entire logs into the conclusion.

## Output requirements

- Use the format: Repository -> Status -> Cause -> Next action
- Use American English by default
- Do not directly modify code
- Do not treat `L1/L2` reports as business acceptance conclusions

## Validation checklist

- Are environment issues distinguished from code issues?
- Are next actions executable?
- Does the output avoid repeating lengthy logs?
