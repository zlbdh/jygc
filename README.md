# Agent Harness 控制仓公开脱敏版

这是一个从本机真实多仓协作控制仓整理出的公开脱敏版，用来展示 Agent / Workflow / Skill / MCP 如何参与工程协作、任务派发、验证和证据沉淀。仓库中的项目名、组织名、远程地址、仓库角色和路径均已泛化为示例信息；真实业务仓代码、运行快照、截图、日志、报告和可识别业务资料未包含在内。

`example-product-harness` 是示例产品 7 仓研发的控制平面。  
它不承载业务主代码，而是统一承载 **需求受理、跨仓影响分析、任务拆解、本地基线、跨仓验收、发布治理和知识回灌**。

当前纳入控制平面的业务仓有：

- `example-product-backend`：后端微服务
- `example-product-web-portal`：企业平台 PC 端
- `example-product-admin-web`：示例产品大平台管理端
- `example-product-mobile-a`：企业端移动 App
- `example-product-mobile-b`：商家端 App
- `example-product-mobile-c`：服务员端 App
- `example-product-miniapp`：消费者小程序

## 仓库定位

- 统一管理跨仓需求的 `change-id`
- 固化 Agent、Workflow、Skills、MCP 的控制平面设计
- 提供 7 仓本地拉齐、契约发现和本地风险矩阵
- 统一管理任务卡、验收记录、发布单和复盘记录
- 让研发过程从“口头协作”升级为“结构化、可审计、可回放”

## 当前成熟度快照

- `backend`、`web-portal`、`admin-web`、`mobile-a`、`mobile-b`：当前主链路已进入本地基线 `L2 PASS`
- `backend`、`mobile-a`、`mobile-b`：允许本地 `L1 WARN`，原因通常是未提交改动而不是命令链失败
- `mobile-c`、`miniapp`：仍是 `missing-contract` 原型仓，暂不纳入 no-hand-code 主链路
- 控制仓：知识层、本地验证层和 packet-based worker harness 已落位；live MCP、自动锁服务和长期线程服务待补齐

## 关键文档

- [docs/harness-engineering.md](docs/harness-engineering.md)：什么是驾驭工程，以及它在示例产品里的准确含义
- [docs/workflow.md](docs/workflow.md)：标准研发与发布全流程
- [docs/agent-workflow-skill-mcp.md](docs/agent-workflow-skill-mcp.md)：当前与目标的 Agent / Workflow / Skill / MCP 清单
- [docs/worker-harness-v1.md](docs/worker-harness-v1.md)：V1 本地 worker 调度、packet 和 review 运行面
- [docs/official-harness-mapping.md](docs/official-harness-mapping.md)：官方 Harness Engineering 到示例产品当前项目的映射、差距与下一步
- [docs/memory-governance.md](docs/memory-governance.md)：记忆分层、事实源和写回规则
- [docs/rule-precedence.md](docs/rule-precedence.md)：规则优先级、冲突处理和元信息要求
- [docs/harness-sop.md](docs/harness-sop.md)：示例产品“驾驭工程”标准 SOP
- [docs/module-practical-template.md](docs/module-practical-template.md)：新增模块时的完整实战模板
- [docs/architecture.md](docs/architecture.md)：控制平面与七仓协作架构
- [docs/command-contract.md](docs/command-contract.md)：各仓最小命令契约
- [docs/cross-repo/README.md](docs/cross-repo/README.md)：跨仓链路、依赖图与契约索引入口

## 目录总览

```text
.
├── AGENTS.md
├── repos/
│   └── repos.yaml
├── docs/
├── standards/
├── templates/
├── changes/
├── evals/
├── reports/
├── release/
├── mcp/
└── scripts/
```

## 记忆与规则模型

当前控制平面采用固定的分层模型：

- 仓库产物是**长期记忆**
- 线程与聊天记录是**短期记忆**
- MCP 是**外部只读上下文**
- Skills 是**可复用执行配方**
- Workflow 是**编排顺序**
- 规则是**边界、门禁与冲突处理**

默认不建设“万能记忆库”，而是把事实沉淀到控制仓与业务仓各自的事实源里。

## 快速开始

1. 校验控制仓结构和业务仓清单：

```powershell
.\scripts\checks\validate-repos.ps1
.\scripts\bootstrap\verify-workspace.ps1
```

2. 干跑或执行 7 仓拉齐：

```powershell
.\scripts\bootstrap\clone-repos.ps1 -DryRun
.\scripts\bootstrap\sync-repos.ps1 -DryRun
```

3. 发现各仓契约并输出基线报告：

```powershell
.\scripts\checks\discover-contracts.ps1
.\scripts\checks\run-local-baseline.ps1
```

4. 创建并校验一个新变更单：

```powershell
.\scripts\bootstrap\init-change.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -Title "初始化研发控制仓"
.\scripts\checks\validate-change.ps1 -ChangeId CHG-2026-0001-bootstrap-harness
```

5. 为某个变更生成本地 worker dispatch 包，并可做 no-hand-code 烟测：

```powershell
.\scripts\orchestrator\dispatch-change.ps1 -ChangeId CHG-2026-0001-bootstrap-harness
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -RepoId backend -PrintPacket
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -RepoId backend -Execute -NoCodeChanges -Ephemeral
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-2026-0001-bootstrap-harness
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -RepoIds backend -Execute -Ephemeral
```

## 控制平面组件

- `repos/repos.yaml`：七仓定位与命令发现唯一事实源
- `docs/`：全局概念、架构、流程、清单
- `standards/`：全局门禁与分端规则
- `templates/`：变更、设计、执行状态、验收、验证、发布、复盘模板
- `.agent/skills/`：控制仓级流程型 skills
- `mcp/`：只读、非生产的 MCP 蓝图与接入策略
- `reports/`：本地验证与诊断输出

## 本地代码布局约定

业务仓本地工作副本统一放在 `D:\workspace\agent-harness\repos\` 下，但默认不纳入控制仓版本控制。  
业务仓元数据只认 [repos/repos.yaml](repos/repos.yaml)。

每个变更默认还会生成 [execution.yaml](templates/execution.yaml) 对应的实例，用来记录：

- 当前阶段
- 当前阶段 owner
- repo owner
- 写入边界
- worktree / branch
- 锁状态
- 快照时间

## 本地验证报告

本地拉齐、自检和基线验证结果统一输出到：

- [reports/README.md](reports/README.md)
- `D:\workspace\agent-harness\reports\local-validation\`

这些报告是“先本地、后生产”的最低门禁，不是可选参考项。
