# MCP 蓝图目录

当前控制仓**尚未接入任何 live MCP**。  
本目录只保存当前阶段允许规划和接入的只读、非生产 MCP 蓝图。

当前目录中的事实源分为两类：

- 蓝图说明：`blueprints/`
- 机器可读目录：[catalog.yaml](mcp/catalog.yaml)

## 当前阶段允许规划的 MCP

- `db-schema-readonly`
- `api-contract-readonly`
- `config-readonly`
- `observability-readonly`

## 当前阶段禁止的 MCP

- 生产数据库
- 生产配置中心
- 生产 Redis / MQ
- 默认具备写权限的运维类 MCP

## 接入顺序建议

1. `api-contract-readonly`
2. `db-schema-readonly`
3. `config-readonly`
4. `observability-readonly`

## 使用原则

- 先做蓝图，再做接入
- 先做开发/测试环境，再考虑更高等级环境
- 先做只读，再谈更强能力
- 所有 MCP 输出都必须带来源与时间戳
