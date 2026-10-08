---
name: postmortem-to-regression
description: Turn incidents, rework, missed tests, and postmortems into proposed rule updates, template updates, regression cases, and skill improvements. Use when Codex needs to turn a `postmortem.md` or failed verification history into concrete knowledge feedback artifacts.
---

# Postmortem To Regression

## Overview

Convert past failures into checks that can catch the same problems next time. Postmortems must lead to practical safeguards.

## Execution steps

1. Read `postmortem.md`, `verification/result.md`, `acceptance.md`, related baseline reports, and rule documents.
2. Identify the issue category:
   - Missing rule
   - Missing template
   - Missing regression coverage
   - Missing skill
3. Provide at least one actionable feedback item with a specific target file or directory.
4. For issues limited to one repository, specify whether the improvement belongs in the control repository or business repository.

## Output requirements

- Use the format: Issue -> Root cause -> Feedback target -> Next action
- Propose at least one regression case or rule update
- Turn postmortems into concrete actions
- Do not change release conclusions without human confirmation

## Validation checklist

- Are issues converted into concrete artifacts?
- Is the target feedback layer identified?
- Does the output go beyond retelling lessons learned?
