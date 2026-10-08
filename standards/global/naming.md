---
scope: control-plane
owner: harness-core
applies_to:
  - all-changes
  - all-release-notes
precedence: 2
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# Naming conventions

## 1. Change record ID

Standard format:

```text
CHG-YYYY-NNNN-slug
```

Examples:

```text
CHG-2026-0001-bootstrap-harness
CHG-2026-0102-platform-order-routing
```

Notes:

- `YYYY`: Year
- `NNNN`: Four-digit sequence number
- `slug`: Lowercase English letters and hyphens

## 2. Change directory naming

The directory name must exactly match `change-id`.

## 3. Task card naming

Use repository IDs consistently:

- `backend.md`
- `web-portal.md`
- `admin-web.md`
- `mobile-a.md`
- `mobile-b.md`
- `mobile-c.md`
- `miniapp.md`

## 4. Evaluation case naming

Standard format:

```text
<domain>-<number>-<slug>.md
```

Recommendations:

- `WEB-001-platform-approval-sync.md`
- `API-001-platform-order-routing.md`
- `MOB-001-enterprise-todo-visible.md`

## 5. Release record naming

Standard format:

```text
REL-YYYY-NNNN.md
```
