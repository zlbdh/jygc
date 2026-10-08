---
name: memory-router
description: Determine which sources of truth to read first, distinguish long-term memory from short-term context, and identify gaps and required writeback for the current control-repository task. Use when Codex needs to decide what to read first across `docs/`, `standards/`, `changes/`, business-repo rules, reports, and MCP blueprints before implementation or review.
---

# Memory Router

## Overview

Use a structured reading order to locate the context needed for the task.

## Execution steps

1. Read `AGENTS.md`, `docs/memory-governance.md`, `docs/rule-precedence.md`, and the target `changes/<change-id>/`.
2. Determine which memory layers the current task needs:
   - Global memory
   - Cross-repository memory
   - Change memory
   - Repository / module memory
   - Verification memory
   - External context
3. Provide a recommended reading order, source-of-truth inventory, known gaps, and files requiring writeback.
4. Explicitly mark unsourced or outdated information as a lead rather than a fact.

## Output requirements

- Use the format: Memory layer -> Path -> Purpose
- Clearly distinguish facts, assumptions, and items needing confirmation
- Identify conclusions that must be written back to the control repository
- Do not directly modify business-repository code

## Validation checklist

- Are long-term and short-term memory distinguished?
- Are required structured writeback artifacts identified?
- Does the output avoid treating conversations as authoritative system facts?
