---
scope: repo
owner: admin-web-owner
applies_to:
  - admin-web
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `admin-web` Platform administration portal rules

## 1. Scope

These rules apply to `example-product-admin-web`.

## 2. Current assumptions

Based on current requirements, `admin-web` provisionally uses this baseline:

- Vue 3
- Vite
- Element Plus
- Platform-wide administration perspective

These initial rules are placeholders. Refine them against the actual code structure once the local repository is available.

## 3. Business boundaries

`admin-web` provides platform-level capabilities. Distinguish these from an enterprise's own administration interface:

- Enterprise approval
- Service/product approval
- Order routing and oversight
- Platform consumer operations
- Platform-wide analytics and settlement

## 4. Implementation principles

- Distinguish platform fields, menus, and status names from enterprise equivalents
- Explicitly record every platform-to-enterprise synchronization point in the change record
- Platform pages prioritize oversight, approval, and routing; do not reuse enterprise-specific semantics

## 5. Minimum verification requirements

- `npm run build`
- Include critical approval and synchronization flows in the golden regression suite

## 6. Items needing confirmation

- Actual script names
- Actual directory structure
- lint / typecheck commands
