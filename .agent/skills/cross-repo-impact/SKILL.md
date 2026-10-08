---
name: cross-repo-impact
description: Create or correct `impact.yaml` for example-product requests spanning multiple repositories, identifying affected repositories, modules, interfaces, tables, configurations, and dependency order. Use when Codex needs to analyze whether a change touches `backend / web-portal / admin-web / mobile-a / mobile-b / mobile-c / miniapp` and produce a structured cross-repo impact record before implementation.
---

# Cross Repo Impact

## Overview

Document the request's repository impact in a structured `impact.yaml`, adding lightweight design notes when needed.

## Execution steps

1. Read `brief.md`, `repos/repos.yaml`, `docs/architecture.md`, and `docs/command-contract.md`.
2. Identify affected repositories, modules, interfaces, tables, configurations, and dependency order.
3. Highlight high-risk interactions such as cross-platform state synchronization, approvals, order flows, exports, and idempotency.
4. Draft a lightweight `design.md` if needed, without skipping `impact.yaml`.

## Output requirements

- Update `impact.yaml` first
- Explicitly specify `affected_repos` and `dependency_order`
- Mark uncertain items as `Needs confirmation`; do not fabricate facts
- Do not directly change business-repository code

## Validation checklist

- Are all affected repositories covered?
- Are interface and configuration impacts documented?
- Are release-order dependencies identified?
- Are cross-platform risks explicitly documented?
