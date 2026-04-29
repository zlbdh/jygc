---
scope: control-plane
owner: harness-core
applies_to:
  - all-mcp-blueprints
precedence: 1
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# MCP 安全规则

## 1. 当前阶段总原则

- 只允许设计和接入只读 MCP
- 只允许开发或测试环境
- 默认不接生产
- 默认不接写权限

## 2. 允许规划的 MCP 类型

- `db-schema-readonly`
- `api-contract-readonly`
- `config-readonly`
- `observability-readonly`

## 3. 禁止接入的类型

- 生产数据库
- 生产配置中心
- 生产 Redis
- 生产 MQ
- 默认可写的文件类或运维类 MCP

## 4. 接入前检查项

- 是否明确环境是开发或测试
- 是否明确能力是只读
- 是否有最小权限账号
- 是否不会暴露敏感密钥
- 是否有明确的日志和审计范围
- 是否能返回来源与时间戳
- 是否能区分实时读与快照读

## 5. 当前阶段的使用规则

- MCP 输出默认不能直接形成发布结论
- 所有 MCP 事实必须回填来源、环境和读取时间
- MCP 只提供上下文，不替代仓库中的长期记忆
- 没有来源的 MCP 结果必须视为无效线索
