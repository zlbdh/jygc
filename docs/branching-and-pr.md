# 分支与 PR 规范

## 1. 控制仓分支命名

控制仓分支统一使用：

```text
codex/<change-id>-<topic>
```

示例：

```text
codex/CHG-2026-0001-bootstrap-harness
```

## 2. 业务仓分支命名

业务仓分支统一使用：

```text
codex/<change-id>-<repo>-<topic>
```

示例：

```text
codex/CHG-2026-0102-hd-order-routing
codex/CHG-2026-0102-admin-web-enterprise-review
codex/CHG-2026-0102-mobile-a-todo-sync
```

## 3. PR 标题规范

业务仓 PR 标题统一格式：

```text
[<change-id>][<repo>] <简短说明>
```

示例：

```text
[CHG-2026-0102][backend] 新增平台订单路由状态同步接口
```

## 4. Commit message 建议

建议格式：

```text
<type>(<repo>): <说明> [<change-id>]
```

示例：

```text
feat(backend): 补充平台订单路由回传逻辑 [CHG-2026-0102]
docs(harness): 初始化控制仓骨架 [CHG-2026-0001]
```

## 5. 变更单引用规则

- 每个业务仓 PR 必须在描述里引用 `change-id`
- 必须附上控制仓中的任务卡路径
- 跨仓需求的所有 PR 最终都要回填到发布单

## 6. 合并前检查

PR 在进入人工审查前，至少要满足：

- 对应任务卡已存在
- 关联 `change-id` 已写入 PR
- 本仓最小验证结果已记录
- 跨仓风险已回填到控制仓
