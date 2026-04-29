# 《“驾驭工程”标准 SOP》

## 1. 目标

把示例产品研发从“谁想到就去哪个仓改”升级成“控制仓统一受理、分仓执行、跨仓验收、结构化发布、持续回灌”。

适用范围：

- 控制仓：`D:\workspace\agent-harness`
- 业务仓：`backend / web-portal / admin-web / mobile-a / mobile-b / mobile-c / miniapp`

## 2. 核心原则

- 控制仓是唯一研发入口
- 仓库产物是长期记忆，聊天记录不是系统事实
- `brief / impact / execution / design / tasks` 构成变更合同
- 单仓绿灯不等于需求完成
- 没有回滚方案不形成发布结论
- 事故和返工必须回灌到规则、模板、回归或 skill

## 3. 角色分工

### 3.1 业务与管理角色

- 产品/业务：提出需求、定义成功标准、确认验收结论
- 技术负责人：把关影响分析、依赖顺序和发布风险
- 人工 reviewer：审查正确性、风险和可发布性

### 3.2 治理类 Agent

- `change-intake-agent`：整理 `brief.md`
- `impact-design-agent`：整理 `impact.yaml`、`design.md`、`execution.yaml`
- `verification-agent`：整理验证结果与验收记录
- `release-agent`：整理发布单、回滚方案和观察点
- `knowledge-agent`：整理 `postmortem.md` 与回灌项

### 3.3 执行类 Agent

- `backend-exec-agent`
- `web-exec-agent`
- `admin-web-exec-agent`
- `mobile-a-exec-agent`
- `mobile-b-exec-agent`

### 3.4 原型类 Agent

- `mobile-c-planning-agent`
- `miniapp-planning-agent`

当前阶段 `mobile-c`、`miniapp` 仍按原型仓治理，不进入正式执行 Agent 池。

## 4. 标准流程

### 阶段 0：本地基线准备

目标：确认仓库状态、命令契约和历史红灯。

执行命令：

```powershell
.\scripts\checks\validate-repos.ps1
.\scripts\bootstrap\verify-workspace.ps1
.\scripts\checks\discover-contracts.ps1
.\scripts\checks\run-local-baseline.ps1
```

产物：

- `reports/local-validation/*`

门禁：

- 未完成本地基线的仓，不进入发布前置判断

### 阶段 1：创建变更单

目标：让需求先进入控制仓，而不是直接进入业务仓。

执行命令：

```powershell
.\scripts\bootstrap\init-change.ps1 -ChangeId CHG-YYYY-NNNN-slug -Title "需求标题"
```

默认生成：

- `brief.md`
- `impact.yaml`
- `execution.yaml`
- `design.md`
- `acceptance.md`
- `tasks/*.md`
- `verification/result.md`
- `postmortem.md`

门禁：

- 没有 `change-id` 不开工

### 阶段 2：需求受理

目标：把模糊需求变成结构化目标。

主文件：

- `brief.md`

必须写清：

- 业务目标
- 用户角色
- 成功标准
- 非目标
- 风险说明

主责任：

- `change-intake-agent`

### 阶段 3：影响分析与执行编排

目标：明确会影响哪些仓、依赖顺序是什么、谁能写哪里。

主文件：

- `impact.yaml`
- `design.md`
- `execution.yaml`

必须写清：

- 影响仓、模块、接口、配置、表
- 依赖顺序
- 当前阶段 owner
- repo owner
- write scope
- branch / worktree
- runtime_type / registry_ref
- worker_result / review_result
- lock state

主责任：

- `impact-design-agent`

门禁：

- 没有 `impact.yaml` 不拆任务
- 没有 `execution.yaml` 不并发开发

### 阶段 4：任务拆分

目标：按仓拆分成可执行任务卡。

主文件：

- `tasks/<repo>.md`

每张任务卡必须包含：

- 输入
- 输出
- 改动边界
- 禁止改动项
- 本仓验证命令
- 建议执行 Agent

门禁：

- 没有任务卡不进入业务仓开发

### 阶段 4.5：Worker 派工

目标：把 `execution.yaml` 中的 repo owner 角色派发成真实 worker packet。

执行命令：

```powershell
.\scripts\orchestrator\dispatch-change.ps1 -ChangeId CHG-YYYY-NNNN-slug
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -PrintPacket
```

产物：

- `runtime/dispatch-state.json`
- `runtime/packets/<repo>-worker.md`
- `verification/workers/<repo>.md`

门禁：

- 没有 registry_ref / runtime_type / worker_result / review_result，不进入 worker 流程
- worker packet 生成失败，不进入对应 repo 的 no-hand-code 执行

### 阶段 5：分仓执行

目标：按仓边界开发，实现并发但不互踩。

规则：

- 一个 Agent 只写一个业务仓
- 同一时间只允许一个 Agent 写一个业务仓
- 多个 Agent 不能共享同一个可写 worktree
- 所有执行边界必须在 `execution.yaml` 里登记

主责任：

- 对应 repo 的执行 Agent

### 阶段 6：仓内验证

目标：每个仓先对自己负责。

典型验证：

- `backend`：`mvn test` / `mvn package`
- `web-portal`、`admin-web`：`npm run build*`
- `mobile-a`、`mobile-b`：`lint / test`

主文件：

- `verification/result.md`

门禁：

- 仓内验证不过，不宣布开发完成

### 阶段 7：跨仓验收

目标：验证完整业务链路，而不是单仓结果。

主文件：

- `acceptance.md`
- `verification/result.md`

要求：

- 按用户流程逐步记录
- 每步都写预期结果和实际结果
- 显式记录遗留风险

门禁：

- 单仓通过不等于需求完成

### 阶段 8：发布治理

目标：把“能跑”变成“能安全上线”。

主文件：

- 发布单实例

必须包含：

- 涉及仓库与分支/提交
- 数据库/配置变更
- 发布顺序
- 回滚步骤
- 发布后观察点

门禁：

- 没有回滚方案，不进入上线准备
- 没有验收记录，不形成发布结论

### 阶段 9：复盘回灌

目标：把问题变成系统改进。

主文件：

- `postmortem.md`

至少回灌一项：

- 新规则
- 新模板
- 新回归
- 新 skill

门禁：

- 问题不能只停留在聊天记录里

## 5. 并发与冲突处理

### 5.1 可共享

- 读取同一规则文档
- 读取同一 skill
- 读取同一只读 MCP
- 读取同一基线报告

### 5.2 不可共享

- 同时写同一个控制仓主产物
- 同时写同一个业务仓
- 多个 Agent 共享一个可写 worktree

### 5.3 冲突解决

- 通过 `execution.yaml` 记录 owner、write scope、锁状态
- 第二个 Agent 只能读，或以评审意见附加，不能并写主文件
- 同级规则冲突必须写入 `impact.yaml` 或 `design.md` 的 `待确认`

## 6. 规则优先级

固定优先级：

1. 安全 / 环境规则
2. 变更合同：`brief / impact / execution / design / tasks`
3. 跨仓架构与发布门禁
4. 业务仓规则
5. 模块规则 / 示例实现
6. Skill 配方
7. 风格偏好

原则：

- 高优先级覆盖低优先级
- Skill 不能覆盖 repo rule
- repo rule 不能覆盖安全与发布门禁

## 7. 完成标准

一个需求只有同时满足以下条件，才算“完成”：

- 变更单结构完整
- `brief.md` 完整
- `impact.yaml` 完整
- `execution.yaml` 完整
- `design.md` 完整
- 任务卡齐全
- 仓内验证有记录
- 跨仓验收有记录
- 发布单和回滚说明齐全
- 复盘已落档或明确无需复盘

## 8. 一句话操作法

先在控制仓定义清楚，再在业务仓执行，再回控制仓验收、发布和复盘。
