---
name: rule-resolver
description: Identify applicable rule layers, precedence, and conflicts for the current task, and list items requiring confirmation. Use when Codex needs to resolve which global, cross-repo, repo-local, module, or skill rules apply before implementation, review, or release.
---

# Rule Resolver

## Overview

Determine which rules apply so skills, repository rules, and global gates work together consistently.

## Execution steps

1. Read `docs/rule-precedence.md`, `standards/`, the target business repository's rules, and the relevant `changes/<change-id>/` files.
2. List applicable rules in precedence order.
3. Identify conflicts:
   - Safety or environment rules versus business implementation
   - Cross-repository gates versus repository conventions
   - Repository rules versus skill procedures
4. Report conflict resolutions and items needing confirmation. Recommend recording same-level conflicts in `impact.yaml` or `design.md`.

## Output requirements

- Use the format: Rule -> Precedence -> Reason it applies -> Resolution
- Do not let lower-priority rules override higher-priority rules
- Mark cases that cannot be resolved automatically as `Needs confirmation`
- Do not directly approve releases

## Validation checklist

- Are rules sorted by precedence?
- Does the result recognize that skills cannot override repository rules?
- Are same-level conflicts explicitly escalated?
