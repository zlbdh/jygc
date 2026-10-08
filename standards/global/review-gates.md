---
scope: review
owner: harness-core
applies_to:
  - all-changes
precedence: 3
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# Human review gates

Human review evaluates results, risks, and release readiness. AI remains responsible for organizing the structured evidence.

## Required checks

- The change record structure is complete
- Impact analysis is clear
- `execution.yaml` is structurally complete with clear ownership boundaries
- Task cards match the repositories actually changed
- Minimum repository verification results are recorded
- Cross-platform acceptance results are recorded
- Risks and rollback instructions are clearly documented

## Key review questions

- Does implementation match the requested scope?
- Were any necessary cross-repository changes missed?
- Are any release-order dependencies undocumented?
- Could existing production workflows be disrupted?
- Have temporary assumptions been incorrectly recorded as long-term rules?
