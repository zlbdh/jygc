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

# 命名规范

## 1. 变更单 ID

统一格式：

```text
CHG-YYYY-NNNN-slug
```

示例：

```text
CHG-2026-0001-bootstrap-harness
CHG-2026-0102-platform-order-routing
```

说明：

- `YYYY`：年份
- `NNNN`：四位流水号
- `slug`：小写英文和连字符

## 2. 变更目录命名

目录名必须与 `change-id` 完全一致。

## 3. 任务卡命名

固定使用仓库 ID：

- `backend.md`
- `web-portal.md`
- `admin-web.md`
- `mobile-a.md`
- `mobile-b.md`
- `mobile-c.md`
- `miniapp.md`

## 4. 评测用例命名

统一格式：

```text
<domain>-<编号>-<slug>.md
```

建议：

- `WEB-001-platform-approval-sync.md`
- `API-001-platform-order-routing.md`
- `MOB-001-enterprise-todo-visible.md`

## 5. 发布单命名

统一格式：

```text
REL-YYYY-NNNN.md
```
