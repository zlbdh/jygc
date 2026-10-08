---
scope: control-plane
owner: harness-core
applies_to:
  - all-changes
precedence: 2
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# Change lifecycle

Each change record progresses through these states:

1. `draft`
   - Only basic background is available; impact analysis is incomplete
2. `analyzing`
   - Completing `impact.yaml`, `design.md`, and `execution.yaml`
3. `planned`
   - Task cards are complete; repository execution may begin
4. `implementing`
   - Work has started in at least one business repository
5. `verifying`
   - Repository self-tests are complete; cross-platform acceptance is underway
6. `ready-for-review`
   - A release conclusion is ready for human review
7. `released`
   - Released and documented
8. `closed`
   - Postmortem complete; lifecycle closed

## State transition rules

- Do not move from `draft` to `planned` without `impact.yaml`
- Do not move from `draft` to `planned` without `execution.yaml`
- Do not move from `analyzing` to `planned` without task cards
- Do not enter `ready-for-review` without acceptance results
- Do not enter `closed` without a release or abandonment conclusion
