# 跨仓契约索引

## 1. 契约类型

当前控制平面主要关注以下跨仓契约：

- 代码与命令契约：`repos/repos.yaml`、`docs/command-contract.md`
- 变更契约：`brief.md`、`impact.yaml`、`execution.yaml`、`design.md`、`tasks/*.md`
- 验收契约：`acceptance.md`、`verification/result.md`
- 发布契约：发布单、回滚说明、观察点
- 外部上下文契约：MCP 目录与蓝图

## 2. 当前可依赖的契约入口

| 类型 | 入口 | 当前状态 |
|------|------|---------|
| 仓库定位 | `repos/repos.yaml` | 已落地 |
| 命令契约 | `docs/command-contract.md` | 已落地 |
| 本地基线 | `reports/local-validation/` | 已落地 |
| 变更结构 | `templates/` 与 `changes/` | 已落地 |
| 只读 MCP 目录 | `mcp/catalog.yaml` | 本次补齐 |
| 业务仓局部规则 | 各仓 `.agent/rules` 与 README | 已存在但未统一索引 |

## 3. 当前缺口

- `backend` 的接口契约还没有统一导出索引
- `web-portal / admin-web` 的页面/路由契约仍主要在代码与页面实现里
- `mobile-a / mobile-b` 的移动端页面、导航、API 契约尚未形成控制仓级索引
- `mobile-c / miniapp` 仍缺标准工程契约
