---
name: task-card-generator
description: Break work into repository-level task cards and create or refine inputs, outputs, boundaries, prohibited changes, and verification commands in `tasks/*.md`. Use when Codex needs to turn an approved `impact.yaml` and design into executable repo-level task cards for backend, web, mobile, or governance work.
---

# Task Card Generator

## Overview

Break cross-repository requests into repository-level execution units with clear implementation boundaries and verification methods.

## Execution steps

1. Read `impact.yaml`, `design.md`, `repos/repos.yaml`, and the target `tasks/` directory.
2. Complete task cards only for affected repositories. Keep placeholders or mark unaffected repositories as out of scope.
3. Specify inputs, outputs, change boundaries, prohibited changes, and repository verification commands.
4. Document required pre-release evidence in the task card in advance.

## Output requirements

- Update `tasks/<repo-id>.md` by default
- Each task card covers one repository
- Prefer command contracts registered in `repos.yaml`
- Do not directly issue cross-repository acceptance conclusions

## Validation checklist

- Are tasks organized by repository rather than by person?
- Are boundaries and prohibited changes clear?
- Are verification commands included?
- Is dependency order represented?
