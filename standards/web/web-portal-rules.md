---
scope: repo
owner: web-owner
applies_to:
  - web-portal
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `web-portal` Enterprise web portal rules

## 1. Scope

These rules apply to `example-product-web-portal`.

## 2. Technical baseline

- Vue 3
- Vite
- Element Plus
- Pinia
- Axios

## 3. Page implementation principles

- Reuse existing administration-interface interaction patterns for new pages
- Follow existing administration interaction patterns and directory organization for lists, forms, and detail pages
- Prefer the `exportAndPreview` direct-link pattern for all exports

## 4. Change considerations

- Consider page, button, and menu permissions together
- Define search criteria, pagination, and empty states for list pages
- Keep form fields consistent with backend validation rules
- Document state synchronization points in the control repository when platform and enterprise portals interact

## 5. Minimum verification requirements

- `npm run build:prod`
- Include critical workflows in the golden regression suite

## 6. Future additions

- `lint`
- `typecheck`
- Map Playwright automated cases to actual pages
