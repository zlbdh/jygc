# 示例产品 Harness 仓 AI 协作说明

本仓是示例产品多仓研发的“驾驶舱”，所有 AI 助手在这里工作时都必须遵守以下规则。

## 1. 先看什么

收到任务后，默认按以下顺序读取上下文：

1. [repos/repos.yaml](repos/repos.yaml)
2. [docs/harness-engineering.md](docs/harness-engineering.md)
3. [docs/workflow.md](docs/workflow.md)
4. [docs/agent-workflow-skill-mcp.md](docs/agent-workflow-skill-mcp.md)
5. [docs/memory-governance.md](docs/memory-governance.md)
6. [docs/rule-precedence.md](docs/rule-precedence.md)
7. 对应 `changes/<change-id>/` 下的文件，尤其是 `execution.yaml`
8. [docs/cross-repo/README.md](docs/cross-repo/README.md) 及相关索引
9. 受影响仓对应的规则文档
10. 最新的 `reports/local-validation/` 报告（如果任务与本地验证相关）

## 2. 不允许的行为

- 没有 `change-id`，不允许直接在业务仓开工
- 跳过 `impact.yaml`，不允许宣布进入开发
- 没有 `execution.yaml`，不允许并发拆派执行 Agent
- 只做单仓自测，不允许宣布跨端需求完成
- 没有回滚说明，不允许形成发布结论
- 不允许把七个业务仓主代码直接提交到本仓
- 不允许把生产数据库、Redis、RabbitMQ、Nacos、MinIO 作为默认验证环境
- 不允许两个 Agent 同时写同一个控制仓主产物
- 不允许多个 Agent 共享同一个可写 worktree

## 3. 必须产出的最小文件

每个变更至少要有：

- `brief.md`
- `impact.yaml`
- `execution.yaml`
- `acceptance.md`
- 至少一个任务卡
- `verification/result.md`

## 4. 任务拆解规则

- 一个跨仓需求，必须拆成 repo 级任务卡
- 每张任务卡只描述一个仓的输入、输出、边界和验证命令
- 如果跨仓有顺序依赖，必须写在 `impact.yaml`
- 如果存在并发执行，必须在 `execution.yaml` 中显式记录 owner、write_scope、branch、worktree 和 lock_state

## 5. 本仓职责边界

本仓负责：

- 需求管理
- Agent / Workflow / Skill / MCP 控制平面设计
- 设计决策归档
- 任务编排
- 回归用例
- 发布门禁
- AI 规则
- 本地化拉齐与安全基线验证

本仓不负责：

- 存放业务仓主代码
- 替代业务仓本地 README/规则
- 替代业务仓本地 CI
- 默认连接生产环境或生产 MCP

## 6. 控制仓级技能与蓝图

- 控制仓级流程型 skills 放在 `.agent/skills/`
- 当前控制仓级治理型 skills 还包括记忆路由、规则解析和复盘转回归
- MCP 蓝图与接入策略放在 `mcp/`
- 当前阶段只允许设计和接入**只读、非生产**的 MCP
- 当前阶段优先补流程型 skills，不继续扩张页面生成型 skills

## 7. 默认语言与产出风格

- 默认使用中文产出
- 需求、文档、注释、校验结果优先中文
- 保留必要的命令、路径、接口名原文

## 8. 建议执行顺序

1. 先运行 `validate-repos.ps1`
2. 需要本地化时先运行 `clone-repos.ps1 -DryRun`
3. 再运行 `discover-contracts.ps1` 和 `run-local-baseline.ps1`
4. 然后创建或检查变更单，并补齐 `execution.yaml`
5. 用控制仓级 skills 辅助完成 `brief`、`impact`、`task`、`release`、`postmortem` 文档
6. 需要进入 no-hand-code worker 流程时，先运行 `dispatch-change.ps1`
7. 根据任务卡、worker packet 和 `execution.yaml` 进入各业务仓执行
8. 回到控制仓补全验收、发布和复盘结果
