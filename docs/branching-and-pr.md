# Branch and PR Conventions

## 1. Control-repository branch naming

Use this format for control-repository branches:

```text
codex/<change-id>-<topic>
```

Example:

```text
codex/CHG-2026-0001-bootstrap-harness
```

## 2. Business-repository branch naming

Use this format for business-repository branches:

```text
codex/<change-id>-<repo>-<topic>
```

Examples:

```text
codex/CHG-2026-0102-hd-order-routing
codex/CHG-2026-0102-admin-web-enterprise-review
codex/CHG-2026-0102-mobile-a-todo-sync
```

## 3. PR title format

Use this format for business-repository PR titles:

```text
[<change-id>][<repo>] <short description>
```

Example:

```text
[CHG-2026-0102][backend] Add platform order-routing state synchronization API
```

## 4. Recommended commit message format

```text
<type>(<repo>): <description> [<change-id>]
```

Examples:

```text
feat(backend): add platform order-routing response logic [CHG-2026-0102]
docs(harness): initialize control-repository scaffolding [CHG-2026-0001]
```

## 5. Change record references

- Every business-repository PR must reference its `change-id` in the description.
- Include the task-card path in the control repository.
- Record all PRs for a cross-repository request in the release record.

## 6. Pre-merge checks

A PR must meet at least these conditions before human review:

- Its task card exists.
- Its `change-id` is included in the PR.
- Minimum repository verification results are recorded.
- Cross-repository risks are recorded in the control repository.
