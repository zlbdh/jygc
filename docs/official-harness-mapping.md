# 官方 Harness Engineering 到示例产品当前项目的映射

## 1. 目的

这份文档只回答 3 个问题：

1. 官方公开的 Harness Engineering 核心到底是什么
2. 示例产品当前已经做到哪里
3. 下一步怎样把“人不手写业务代码”真正落到当前项目开发中

它不是总手册替代品，而是当前本地 no-hand-code V1 的落地说明。

## 2. 官方 Harness Engineering 的核心

结合官方公开材料，Harness Engineering 的核心不是“大 prompt”，而是把模型放进一个可持续运行的工程系统里。核心能力可以压缩成 5 件事：

1. 仓库与文档是事实源
2. 有长驻 thread/runtime
3. agent 真正读代码、跑工具、看结果、循环修复
4. UI、日志、指标、trace 等可观测信息对 agent 可见
5. review 可以由 agent-to-agent 完成，人主要做 steering 和批准

对示例产品来说，这 5 件事要被翻译成当前控制仓可落地的工程结构，而不是停留在概念层。

## 3. 映射到示例产品当前项目

### 3.1 Repository knowledge / system of record

官方含义：

- 仓库文档、计划、约束、规则是事实源

示例产品当前映射：

- 控制仓是唯一事实源
- 所有需求先进入 `changes/<change-id>/`
- 业务仓不再直接承接需求入口

当前对应文件：

- `repos/repos.yaml`
- `docs/workflow.md`
- `docs/memory-governance.md`
- `docs/rule-precedence.md`
- `changes/<change-id>/*`

### 3.2 Thread / runtime

官方含义：

- 有长驻 App Server、thread manager、core threads

示例产品当前映射：

- V1 先不做完整 App Server
- 用 `execution.yaml + agent-registry + dispatcher + worker/review packet` 作为本地 thread 替代层

当前对应文件：

- `config/agent-registry.yaml`
- `templates/execution.yaml`
- `scripts/orchestrator/dispatch-change.ps1`
- `scripts/orchestrator/run-role.ps1`
- `scripts/orchestrator/review-worker-output.ps1`

### 3.3 Tool execution loop

官方含义：

- agent 真正执行：读代码、改代码、跑命令、再修复

示例产品当前映射：

- repo worker 在独立 worktree 中执行
- worker 只读任务卡和 write scope
- worker 只在允许路径内修改
- worker 跑本仓最小验证命令

当前对应文件：

- `verification/workers/*.md`
- `runtime/worker-responses/*.json`
- `runtime/review-results/*.json`

### 3.4 Observability

官方含义：

- UI、日志、指标、trace、schema、config 对 agent 可见

示例产品当前映射：

- V1 暂不接 live MCP
- 当前可观测性来源固定为：
  - 代码
  - git diff
  - 命令输出
  - 基线报告
  - worker result
  - review packet

当前状态：

- `mcp/` 仅为 blueprint
- 尚未接入只读 schema / config / observability MCP

### 3.5 Agent-to-agent review

官方含义：

- worker 自审 + reviewer agent 二次审查

示例产品当前映射：

- repo worker 不写主结论
- review worker 读取 diff、worker result、任务卡、一致性约束
- `verification-agent` 汇总写 `verification/result.md`

## 4. 当前已经具备的能力

当前已经具备：

1. 控制平面
2. 本地基线门禁
3. 变更单建模
4. 角色注册表
5. dispatcher
6. repo worker packet
7. review packet
8. 主链路 5 仓 `L2 PASS`
9. 两条真实跨仓试点

当前真实状态：

- `backend / web-portal / admin-web / mobile-a / mobile-b`：主链路 `L2 PASS`
- `backend / mobile-a / mobile-b`：允许 `L1 WARN`
- `mobile-c / miniapp`：`missing-contract`
- 已完成：
  - `CHG-2026-0002-local-refund-audit-pilot`
  - `CHG-2026-0003-local-company-audit-pilot`
  - `CHG-2026-0004-mobile-login-safearea-nohandcode`（当前为单仓 no-hand-code 条件成功样板）
- 最新本地基线报告：
  - `reports/local-validation/20260402-112417-summary.md`

## 5. 当前仍然缺失的部分

当前还没有完全做到官方形态，主要差在运行面：

1. 真正自动启动 repo worker 执行体
2. worker 自动改代码并自动回写结果
3. 自动 review loop 回退给 repo worker
4. 长驻 thread / session 持久化
5. live MCP / observability
6. 团队级默认工作方式
7. 干净 worktree 与主仓脏工作树的严格隔离
8. 环境型假红与真实业务回归的稳定剥离
9. 真正自动启动 repo worker 时的外部运行资源稳定性

所以当前阶段的准确判断是：

- 控制面已经接近成熟
- 运行面仍处于 V1 演进期

## 6. 当前 V1 的“不手写代码”定义

在示例产品当前阶段，“不手写代码”不是指人类完全消失，而是指：

- 业务代码、测试、常规修复默认由 worker 完成
- 人只负责：
  - 选需求
  - 批准变更单
  - 批准 worker 结果
  - 高风险取舍
  - 修 harness 自身

只有以下情况才允许人工直接介入业务代码：

1. harness 自身有 bug
2. worker 多轮失败
3. 规则冲突无法自动决策

## 7. 示例产品下一步的正确落地方向

### 阶段 A：先做单仓 no-hand-code

优先选 `mobile-a`：

- 当前命令链成熟
- 两条试点都已经以 `mobile-a` 为主要改动仓
- 最适合先把 repo worker 真执行链跑顺
- 下一条任务必须收缩为**单仓、单文件、无外部环境依赖**的小任务，并在独立干净 worktree 中执行

目标：

- `dispatch-change -> run-role -Execute -> worker result -> review worker -> verification 汇总`
- 人不手写业务代码
- 当前 `CHG-2026-0004-mobile-login-safearea-nohandcode` 已经证明：
  - repo worker 能在干净 worktree 中真实改出 `ExampleScreen.tsx`
  - V1 已经补上两层关键运行逻辑：
    - 把 **write scope 成功** 与 **仓级历史债阻断** 分开判定
    - 由 dispatcher 用 `snapshot_policy: source_dirty_tracked` 把主仓 tracked dirty snapshot 显式同步到独立 worktree
  - 当前新的剩余阻断已经从“worktree 基线落后”转成“repo worker 真执行时的外部 usage limit / runtime 资源限制”

当前阶段的固定推进顺序是：

1. 保留 `CHG-2026-0004-mobile-login-safearea-nohandcode` 为第一条“有条件通过”样板
2. 在外部 runtime 恢复后，优先直接重跑这条链：
   - `dispatch-change.ps1`
   - `run-role.ps1 -Execute`
   - `review-worker-output.ps1 -Execute`
   - `verification-agent` 更新 `verification/result.md`
3. 只有这条链无条件通过后，才新开第二条 `mobile-a` 单仓 no-hand-code
4. 只有两条 `mobile-a` 单仓任务都稳定成功后，才扩到 `backend + admin-web/web-portal + mobile-a`

在这之前明确不做：

- 多仓并行
- live MCP
- 长驻 App Server / thread manager
- `mobile-c / miniapp` 纳入 no-hand-code 主链路
- 远端提交 / 上线准备

### 阶段 B：再扩到三仓并行

扩到：

- `backend`
- `admin-web/web-portal`
- `mobile-a`

目标：

- 三个 repo 由真实 worker 分别承接
- 主链路继续保持 `L2 PASS`

### 阶段 C：再进入 V2 运行面

只有前两步稳定后，才考虑：

- thread 持久化
- 自动锁服务
- live MCP
- observability worker
- 更像官方 App Server 的形态

## 8. 当前实际开发骨架

当前实际开发已经应按下面的骨架执行：

1. 跑控制仓外层门禁  
   `validate-repos -> verify-workspace -> discover-contracts -> run-local-baseline`
2. 创建并补齐变更单  
   `brief -> impact -> execution -> design -> tasks`
3. dispatcher 读取 `execution.yaml`，为每个受影响仓派发 repo worker
4. repo worker 在独立 worktree 中自动改代码、跑验证、回写 `verification/workers/*.md`
5. review worker / verification-agent 读取 diff、命令输出、worker result，决定是否回退给 repo worker
6. 通过后写 `acceptance.md`、`verification/result.md`、`postmortem.md`
7. 当前阶段到此为止，不进入 commit / push / 上线

## 8.1 当前最新推进

当前已经额外完成：

- `execution.yaml` 支持 `snapshot_policy`
- dispatcher 会把 source repo 的 tracked dirty snapshot 同步到独立 worktree
- `dispatch-state.json` 会记录：
  - `snapshot_policy`
  - `snapshot_source`
  - `snapshot_tracked_files`
  - `snapshot_actions`

这意味着当前最大的运行时误差已经从：

- worker 在落后的 `HEAD` 基线上工作

切换成了：

- repo worker 真执行时是否能稳定拿到外部运行资源并完成一轮完整执行

因此当前最现实的下一步不是再扩概念，而是：

- 保持 `CHG-2026-0004` 的样板状态不变
- 等外部 runtime 恢复后重跑当前链
- 在拿到一轮无阻断的 `repo worker -> review worker -> verification-agent` 结果前，不宣布 no-hand-code V1 成功，也不再新开概念型试点

## 9. 一句话总结

示例产品当前已经把官方 Harness Engineering 的控制面做对了。  
下一步的重点不是再扩方案，而是把 **dispatcher -> 真 worker -> review worker -> verification 汇总** 这条运行链做实，让“不手写业务代码”先在本地主链路里稳定成立。
