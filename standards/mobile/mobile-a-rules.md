---
scope: repo
owner: mobile-a-owner
applies_to:
  - mobile-a
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `mobile-a` Enterprise app rules

## 1. Scope

These rules apply to `example-product-mobile-a`.

## 2. Technical baseline

- React Native
- Expo
- TypeScript
- React Navigation

## 3. Business purpose

The enterprise app extends the enterprise platform to mobile and serves enterprise users rather than consumers.

Prioritize:

- To-do items
- Order and work-order overviews
- Customer and employee management
- Approvals and notifications

## 4. Implementation principles

- Keep page states and API fields consistent with the enterprise platform and backend
- Do not retain extensive temporary mock logic in pages long term
- Access important data through explicit service / API abstractions
- Prioritize to-do and messaging workflows in regression coverage

## 5. Minimum verification requirements

- `npm install`
- `npm run typecheck` (confirm against the local repository)
- Provide Maestro smoke-test entry points for critical workflows

## 6. Current limitations

This initial version documents rules without assuming `mobile-a` is fully available locally. Once the actual repository is available, add:

- Navigation structure mapping
- Actual command contracts
- Mobile smoke-test scripts
