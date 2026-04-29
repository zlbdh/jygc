# Agent / Workflow / Skill / MCP 清单

## 1. 当前已有能力与短板

### 1.1 Agent

- 当前平台内置的是主代理，以及可派生的 `default / explorer / worker` 三类子代理能力
- 当前控制仓已经具备项目级逻辑 Agent 角色，并新增了机器可读的 [agent-registry.yaml](config/agent-registry.yaml)
- 当前仍然**没有平台级自定义新 agent 类型**，项目角色通过 registry 映射到现有运行体
- 当前短板不再是“没有 Agent 角色”，而是**还没有长期线程服务和自动锁服务**

### 1.2 Workflow

当前已经落地的 workflow 有：

- `workspace-baseline-workflow`
  - `clone -> sync -> discover -> baseline`
- `change-intake-workflow`
  - `change-id -> brief -> execution`
- `impact-design-workflow`
  - `brief -> impact -> design -> execution`
- `task-splitting-workflow`
  - `impact/design -> tasks -> repo owner`
- `repo-execution-workflow`
  - `任务卡 -> 分仓执行 -> 仓内验证`
- `cross-repo-acceptance-workflow`
  - `acceptance -> verification/result`
- `release-governance-workflow`
  - `release-note -> rollback -> observe`
- `knowledge-feedback-workflow`
  - `postmortem -> rules/templates/evals/skills`

### 1.3 Skills

当前会话可用系统技能：

- `security-best-practices`
- `imagegen`
- `openai-docs`
- `plugin-creator`
- `skill-creator`
- `skill-installer`

当前业务仓已存在的项目技能：

- `mobile-a`
  - `api-integration-workflow`
  - `business-dictionaries`
  - `ui-ux-pro-max`
  - `yjl-app-generator`
- `mobile-b`
  - `business-dictionaries`
  - `mobile-b-generator`
  - `ui-ux-pro-max`
  - `yjl-app-generator`
- `miniapp`
  - `ui-ux-pro-max`
  - `miniapp-generator`

当前业务仓还存在不少 `.agent/rules` 文件，尤其 `mobile-a` 的业务规则最丰富，但这些规则目前仍然**分散在业务仓内**。

### 1.4 MCP

当前状态：

- 没有任何 MCP 资源
- 没有任何 MCP 模板

这意味着当前的上下文仍然主要来自：

- 本地文件系统
- 控制仓脚本
- 终端输出

## 2. 当前阶段应该补的 Agent

| Agent | 负责范围 | 不负责 |
|------|----------|--------|
| `change-intake-agent` | 把模糊需求整理成 `brief.md` | 不直接改业务代码 |
| `impact-design-agent` | 生成 `impact.yaml` 和轻量 `design.md` | 不直接做发布结论 |
| `backend-agent` | 只负责 `backend` | 不越界改 Web / Mobile |
| `web-agent` | 只负责 `web-portal`、`admin-web` | 不越界改 Backend / Mobile |
| `mobile-agent` | 只负责 `mobile-a`、`mobile-b` | 当前不默认接 `mobile-c` |
| `verification-agent` | 汇总仓内验证、基线报告、验收记录 | 不替代实现 Agent |
| `release-agent` | 生成发布单、回滚单、发布顺序 | 不决定业务是否正确 |
| `knowledge-agent` | 把问题回灌到规则、模板、回归和 skills | 不替代发布动作 |

## 3. 当前阶段应该补的 Workflow

| Workflow | 主要输入 | 主要输出 |
|---------|---------|---------|
| `workspace-baseline-workflow` | `repos.yaml` | 契约发现报告、基线矩阵 |
| `change-intake-workflow` | 原始需求、bug、事故 | `brief.md`、`impact.yaml` |
| `repo-execution-workflow` | `tasks/*.md` | 代码改动、仓内验证结果 |
| `cross-repo-acceptance-workflow` | `acceptance.md` | `verification/result.md` |
| `release-governance-workflow` | 验收结果、分支、配置变更 | 发布单、回滚步骤、观察点 |
| `knowledge-feedback-workflow` | 问题、事故、返工 | `postmortem.md`、新规则、新回归 |

## 4. 当前阶段应该补的控制仓级 Skills

这些 skills 已在控制仓 `.agent/skills/` 中建骨架，目标是优先补**流程型能力**：

| Skill | 触发场景 | 主要输出 |
|------|----------|---------|
| `change-intake` | 需求刚进入控制仓 | `brief.md` 草稿 |
| `cross-repo-impact` | 需要判断影响哪些仓 | `impact.yaml` 草稿 |
| `task-card-generator` | 需要按仓拆任务 | `tasks/*.md` |
| `local-baseline-triage` | 需要读基线报告 | 问题归因与下一步动作 |
| `cross-repo-acceptance-recorder` | 需要补验收记录 | `acceptance.md` / `verification/result.md` |
| `release-package-generator` | 需要形成发布单 | `release-note` / 回滚清单 |
| `memory-router` | 需要决定先读哪些事实源 | 记忆路由清单、事实源顺序、缺口列表 |
| `rule-resolver` | 需要判断适用规则及优先级 | 规则优先级结果、冲突点、待确认项 |
| `postmortem-to-regression` | 需要把事故转成改进项 | 新回归、新规则、新模板、新 skill 候选 |

## 2. 当前与目标 Agent 架构

### 2.1 当前已知库存

- 平台层：主代理 + `default / explorer / worker`
- 控制仓层：角色定义、[agent-registry.yaml](config/agent-registry.yaml) 和本地 `dispatch-change / run-role / review-worker-output` 已落地
- 当前还没有长期线程服务、自动锁服务和 App Server 形态 runtime

### 2.2 当前阶段 v1 Agent

治理类：

- `change-intake-agent`
- `impact-design-agent`
- `verification-agent`
- `release-agent`
- `knowledge-agent`

执行类：

- `backend-exec-agent`
- `web-exec-agent`
- `admin-web-exec-agent`
- `mobile-a-exec-agent`
- `mobile-b-exec-agent`

原型类：

- `mobile-c-planning-agent`
- `miniapp-planning-agent`

### 2.3 长期 v2 Agent

- 线程持久化驱动的调度 Agent
- 锁服务与 worktree 服务
- 兼容矩阵与能力注册表
- 真实跨仓验收自动化 Agent

## 3. 记忆与调用模型

### 3.1 记忆分层

- 仓库产物：长期记忆
- 线程对话：短期记忆
- `reports/`：验证证据记忆
- `postmortem.md`：负面记忆
- MCP：外部只读上下文
- Skills：过程记忆 / 执行配方

### 3.2 调用关系

`用户/产品 -> 控制仓 workflow -> 治理 Agent -> repo 任务卡 -> 执行 Agent -> 验证 Agent -> 发布 Agent -> 知识回灌`

### 3.3 并发原则

- 读共享：多个 Agent 可同时读同一 skill、同一规则文档、同一只读 MCP
- 写独占：同一时间只允许一个 Agent 写一个控制仓主产物，或写一个业务仓
- 共享事实必须带快照：报告、提交、分支、环境和时间戳

### 3.4 当前冲突点

- 多个 Agent 同写 `impact.yaml`
- 多个 Agent 同写 `verification/result.md`
- 多个 Agent 共享一个可写 worktree
- skill 指令覆盖 repo 规则
- 无来源的 MCP 结果被误当成发布依据

## 4. 当前阶段应该补的 MCP

当前阶段只允许设计和接入**只读、非生产**的 MCP：

| MCP | 目的 | 当前状态 |
|-----|------|---------|
| `db-schema-readonly` | 看表结构、字段、索引 | 蓝图已规划，未接入 |
| `api-contract-readonly` | 统一暴露接口契约和样例 | 蓝图已规划，未接入 |
| `config-readonly` | 只读开发/测试配置映射 | 蓝图已规划，未接入 |
| `observability-readonly` | 只读开发/测试日志与 trace | 蓝图已规划，未接入 |

不允许接入：

- 生产数据库 MCP
- 生产配置中心 MCP
- 生产 Redis / MQ MCP
- 任何默认带写权限的 MCP

MCP 目录统一记录在：

- [mcp/catalog.yaml](mcp/catalog.yaml)
- [standards/global/mcp-safety.md](standards/global/mcp-safety.md)

## 5. 当前阶段的优先级

当前阶段的重点不是继续发明更多 Agent，而是先让：

- Agent 有边界
- Workflow 有入口
- Skills 有明确触发场景
- MCP 有只读、非生产的接入策略

它们都服务于同一条受控研发流程。
