# 示例产品 Worker Harness V1

## 1. 定位

Worker Harness V1 是控制仓在“本地验证优先”阶段的运行时补层。  
它不直接实现 OpenAI App Server / JSON-RPC，而是先把当前已有的：

- `execution.yaml`
- 变更单结构
- 本地基线链
- 控制仓 skills

升级成一套**本地 dispatcher + repo worker + review worker + packet/evidence sink** 的可执行协议。

## 2. 当前解决什么问题

当前 `backend-exec-agent / admin-web-exec-agent / mobile-a-exec-agent` 已经是项目里的角色名，但过去它们还只是文档里的 owner 标签。  
V1 补上的是：

- `config/agent-registry.yaml`
  - 把角色变成机器可读实体
- `scripts/orchestrator/dispatch-change.ps1`
  - 把变更单派发成 repo worker packet，并可选择直接启动 worker
- `scripts/orchestrator/run-role.ps1`
  - 单仓 worker 运行入口，可用 `codex exec` 真正执行 repo worker
- `scripts/orchestrator/review-worker-output.ps1`
  - 生成 review packet，并可选择直接启动只读 review worker
- `verification/workers/*.md`
  - 每个 repo worker 的结果沉淀入口
- `runtime/worker-responses/*.json`
  - repo worker 的结构化机器结果
- `runtime/review-results/*.json`
  - review worker 的结构化机器结果

## 3. 使用顺序

### 3.1 先完成控制仓外层门禁

```powershell
.\scripts\checks\validate-repos.ps1
.\scripts\bootstrap\verify-workspace.ps1
.\scripts\checks\discover-contracts.ps1
.\scripts\checks\run-local-baseline.ps1
```

### 3.2 创建并补齐变更单

```powershell
.\scripts\bootstrap\init-change.ps1 -ChangeId CHG-YYYY-NNNN-slug -Title "需求标题"
.\scripts\checks\validate-change.ps1 -ChangeId CHG-YYYY-NNNN-slug
```

### 3.3 生成 worker dispatch 包

```powershell
.\scripts\orchestrator\dispatch-change.ps1 -ChangeId CHG-YYYY-NNNN-slug
```

输出：

- `changes/<change-id>/runtime/dispatch-state.json`
- `changes/<change-id>/runtime/packets/<repo>-worker.md`
- `changes/<change-id>/verification/workers/<repo>.md`

### 3.4 只查看单个 repo worker packet

```powershell
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -PrintPacket
```

### 3.5 真正执行单个 repo worker

```powershell
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -Execute -Ephemeral
```

输出：

- `changes/<change-id>/verification/workers/<repo>.md`
- `changes/<change-id>/runtime/worker-responses/<repo>.json`

说明：

- `-Execute`：真正启动本地 repo worker
- `-Ephemeral`：使用短生命周期会话
- `-NoCodeChanges`：只做 no-hand-code 烟测，不实际改代码

如果该 repo 的 worktree 已经通过 `dispatch-change.ps1` 同步了 `source_dirty_tracked` 快照，后续真实执行应改用：

```powershell
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -Execute -SkipDispatch
```

原因是：

- 已同步 snapshot 的 worktree 天然不再是“干净 HEAD”
- 如果再次使用会触发派工的入口（如 `-EnsureWorktrees`），dispatcher 会因为 target worktree 非干净而将这次执行标记为 `blocked`
- 因此 V1 的正确顺序是：
  1. `dispatch-change.ps1`
  2. `run-role.ps1 -Execute -SkipDispatch`
  3. `review-worker-output.ps1 -Execute`

### 3.6 生成或执行 review worker

```powershell
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-YYYY-NNNN-slug
```

真正执行只读 review worker：

```powershell
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-YYYY-NNNN-slug -Execute -Ephemeral
```

输出：

- `changes/<change-id>/runtime/reviews/<repo>-review.md`
- `changes/<change-id>/runtime/review-state.json`
- `changes/<change-id>/runtime/review-results/<repo>.json`

## 4. Worker 执行协议

### 4.1 repo worker 的固定输入

- `brief.md`
- `impact.yaml`
- `execution.yaml`
- `tasks/<repo>.md`
- 仓规则
- 最近一次本地基线摘要

### 4.2 repo worker 的固定动作

1. 读取任务卡与 write scope
2. 仅在 `allowed_paths` 和 worktree 内执行
3. 修改代码 / 测试 / 契约调用
4. 运行 registry 中定义的本仓最小验证命令
5. 输出符合 schema 的 JSON
6. 由 wrapper 将其落为：
   - `verification/workers/<repo>.md`
   - `runtime/worker-responses/<repo>.json`

### 4.3 review worker 的固定动作

1. 读取 worker result、diff、git status、任务卡
2. 检查是否越界改动
3. 检查是否执行本仓验证
4. 检查是否符合 `impact/design/tasks`
5. 输出符合 schema 的 JSON
6. 由 wrapper 将其落为：
   - `runtime/reviews/<repo>-review.md`
   - `runtime/review-results/<repo>.json`

## 5. 当前边界

- 当前 runtime 仍是**本地优先的 worker harness**
- 当前不接 live MCP
- 当前已支持启动本地 repo worker 与只读 review worker
- 当前还没有长驻 thread manager / App Server
- 当前不自动合并结果进 `verification/result.md`
- 当前默认仍是 **AI 审 + 人批**
- 当前 repo worker 的真实写代码任务必须优先使用**独立且干净的 worktree**
- 当前 repo worker 还不能稳定在主仓脏工作树中完成 no-hand-code 收敛，因此主仓工作树只允许做只读核对，不再作为真实写代码入口

## 6. 当前最重要的原则

- 角色是 registry 实体，不再只是文档名词
- dispatcher 负责派工，不直接决定业务正确性
- worker 只写本仓允许路径
- worker 只在 `execution.yaml` 指向的独立 worktree 内执行真实写代码任务
- repo worker 只回填 `verification/workers/*.md`
- verification-agent 继续负责主验证结论
- `verification/result.md` 仍是 verification-agent 汇总后的主结论，而不是单个 worker 直接覆盖

## 6.1 作用域验证与仓级历史债

V1 的第一批单仓 no-hand-code 任务通常会故意收缩为：

- 单仓
- 单文件或极小 write scope
- 无外部环境依赖

这类任务的主目标是先证明 **repo worker 能在干净 worktree 中真实改出代码**。  
因此在判定时必须区分两层事实：

1. **write scope 内是否成功**
   - worker 是否真的改了允许路径内的代码
   - 目标文件或作用域级验证是否通过
2. **仓库级历史债是否阻断**
   - 仓库级 `npm run lint` / build 失败，是否来自 write scope 外既有问题

当前 V1 规则是：

- 如果 write scope 内改动真实发生，且目标文件级验证通过
- 仓库级失败又被证明来自 write scope 外历史债

则本轮应判定为：

- repo worker：`blocked`
- review worker：`approved`（并明确为“有条件通过”）
- verification-agent：在 `verification/result.md` 中登记为**作用域通过、仓级历史债阻断**

这类场景不得再简单记成“worker 写代码失败”。

如果 `source_dirty_tracked` 已同步成功，但 repo worker 真执行时被外部 `runtime / usage limit` 阻断，则当前 V1 规则改为：

- repo worker：`blocked`
- review worker：`blocked`（`verification_check = blocked_by_runtime`）
- verification-agent：在 `verification/result.md` 中登记为**快照同步已生效，但外部运行资源阻断，本轮不能宣布真正通过**

这类场景也不得误判成“write scope 内实现失败”。

当前 V1 已经补上一层关键运行时策略：

- `snapshot_policy: source_dirty_tracked`

含义是：

- 独立 worktree 不再只基于 git `HEAD`
- dispatcher 会把 source repo 当前**已跟踪文件**的本地未提交快照同步到独立 worktree
- 这样 repo worker 看到的是“当前主仓真实本地基线”，而不是落后的 `HEAD`

当前实现边界：

1. 只同步 **tracked dirty files**
2. 不自动同步 untracked 文件
3. 如果 write scope 依赖 untracked 文件，dispatcher 直接标记 `blocked`
4. 如果 target worktree 不干净或 branch 锚点不一致，也直接 `blocked`

因此当前单仓 no-hand-code 的判定要区分 3 件事：

1. **scope 外历史债**
2. **source_dirty_tracked 是否已同步进 worktree**
3. **repo worker 是否真的在同步后的 worktree 基线上改出了代码**

在这三层完全分开之前，不把仓级门禁失败直接等同为“worker 实现失败”。

## 6.2 `source_dirty_tracked` 的 V1 窄快照策略

`source_dirty_tracked` 解决的是：

- worker 不再只看到落后的 `HEAD`
- worker 能看到 source repo 当前真实的 tracked dirty baseline

`CHG-2026-0004 / mobile-a` 已经证明：  
如果把 source repo 的全部 tracked dirty 文件直接同步进 worktree，会和“单文件 / 极小 write scope”任务天然冲突。

因此当前 V1 已把这条规则收敛为：

1. 默认仍使用 `snapshot_policy: source_dirty_tracked`
2. 但实际同步范围只限于：
   - **当前 write scope 内的 tracked dirty 文件**
3. 对 write scope 外的 tracked dirty 文件：
   - 只记录到 `snapshot_actions`
   - 不再同步进当前 worktree

当前 `dispatch-state.json` 至少要能说明：

- `snapshot_policy`
- `snapshot_source`
- `snapshot_tracked_files`
- `snapshot_actions`

例如：

- `synced-modified:src/screens/ExampleScreen.tsx`
- `ignored-out-of-scope-tracked:94`
- `captured-source-dirty-tracked`

这条窄快照策略的目的，是让下面四层重新一致：

1. worker 实际所在的 worktree 范围
2. 任务卡声明的 write scope
3. review worker 看到的 git diff 范围
4. 本仓验证命令实际覆盖的范围

在这四层没有重新一致之前，不宣布单仓 no-hand-code 成功。

## 6.3 source repo 依赖基线与 worktree 依赖可用性

当前 worktree 的 `node_modules` 不是单独安装的，而是通过 dispatcher 在创建/复用 worktree 时，优先复用 source repo 的 `node_modules`。

这意味着：

1. 如果 source repo 的 `node_modules` 不存在
   - worktree 也不会自动拥有本地依赖
2. 如果 source repo 的 `node_modules` 目录存在，但 `.bin/eslint`、`.bin/expo` 这类本地可执行入口不完整
   - worktree 会继承同样的不完整状态
3. 这类问题在 V1 中应先记为：
   - `blocked_by_environment`
   - 而不是业务实现失败

当前最小实践要求：

- repo worker 进入真实执行前，source repo 至少应具备可用的：
  - `node_modules/.bin/eslint`
  - `node_modules/.bin/expo`（如果 smoke 仍依赖 Expo CLI）
- 如果缺失，应先在 source repo 补齐本地依赖基线，再重跑 worker/review

`CHG-2026-0004` 已经验证过这一点：

- 依赖缺失时，review 应收口到 `blocked_by_environment`
- 依赖补齐后，当前新的主阻断就不再是环境，而会回到 repo worker 自身或外部 runtime

## 6.4 外部 runtime / usage limit 证据收集

当前 V1 的 repo worker 通过 `codex exec` 承接真实执行。  
如果 `codex exec` 没有返回符合 schema 的结构化 JSON，不能只看空白 `raw_response`，还必须保留当次控制台输出。

当前最小规则是：

1. `run-role.ps1` 必须把 `codex exec` 控制台输出落到：
   - `runtime/worker-responses/<repo>-console.log`
2. 如果 worker 未返回结构化 JSON：
   - 先看 `console.log`
   - 再决定是：
     - `blocked_by_runtime`
     - 还是通用外部执行层阻断
3. 如果 console log 中出现例如：
   - `You've hit your usage limit`
   - `try again at`
   - 或同类额度/窗口提示
   则当前应明确记为：
   - **外部 `codex exec` usage limit 阻断**
4. 这类场景不得误判成：
   - write scope 内实现失败
   - review 失败
   - 业务代码不会改

## 7. 当前下一步

当前最重要的目标不是继续扩控制面，而是先把第一条真正的**单仓 no-hand-code**跑成。

固定推进顺序：

1. 先保留 `CHG-2026-0004-mobile-login-safearea-nohandcode` 为第一条“有条件通过”样板，不新开新的单仓 no-hand-code 任务
2. 维持当前 `source_dirty_tracked` 窄快照策略，不再回退到“全量 tracked dirty baseline”
3. 维持 source repo 的本地依赖基线可用
4. 等外部 runtime 恢复后，在同一 worktree 基线上重跑 `CHG-2026-0004 / mobile-a`
5. review worker 只基于当前 diff、worker result 和命令结果给出 `approved / needs_rework / blocked_by_runtime`
6. verification-agent 再汇总写入 `verification/result.md`
7. 只有 `CHG-2026-0004` 无条件通过后，才新开第二条 `mobile-a` 单仓任务

当前已经证明：

- `source_dirty_tracked` 能按 write scope 把 source repo 的 tracked dirty snapshot 同步进独立 worktree
- `dispatch-state.json` 会记录 `snapshot_policy / snapshot_source / snapshot_actions`
- source/worktree 的本地依赖基线可以被恢复
- 当前新的剩余阻断已经不再是 worktree 基线错位或依赖缺失，而是：
  - 外部 `codex exec` runtime / usage limit
  - repo worker 还未在一次无阻断执行中返回结构化 JSON

在 repo worker 真执行链重新满足“快照范围、任务边界、review 范围、验证范围完全一致”，并且外部 runtime 本轮不再阻断之前，不宣布 no-hand-code V1 成功，也不再新开概念型试点。
