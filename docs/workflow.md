# 标准研发工作流

本仓采用“AI 主执行，人审合并”的工作模式。  
所有跨仓需求、发布准备和问题复盘，都必须按下面这 8 条 workflow 组织。

## Workflow 总览

1. `workspace-baseline-workflow`
2. `change-intake-workflow`
3. `impact-design-workflow`
4. `task-splitting-workflow`
5. `repo-execution-workflow`
6. `cross-repo-acceptance-workflow`
7. `release-governance-workflow`
8. `knowledge-feedback-workflow`

## 0. `workspace-baseline-workflow`

用途：拉齐业务仓、发现命令契约、生成本地基线报告。

执行顺序：

1. `scripts\bootstrap\clone-repos.ps1`
2. `scripts\bootstrap\sync-repos.ps1`
3. `scripts\checks\discover-contracts.ps1`
4. `scripts\checks\run-local-baseline.ps1`

输出：

- 仓库状态
- 契约发现报告
- 基线矩阵

要求：

- 默认只在 `D:\workspace\agent-harness\repos\` 下操作
- 默认不连接生产环境
- 本地报告统一输出到 `reports/local-validation/`

未完成本地基线的仓，不应直接用作发布前置判断。

## 1. `change-intake-workflow`

用途：把模糊需求整理成结构化变更单。

执行顺序：

1. 在 `changes/<change-id>/` 创建变更目录
2. 填写 `brief.md`
3. 初始化 `execution.yaml`

核心文件：

- `brief.md`
- `execution.yaml`

门禁：

- 没有 `change-id`，不允许进入业务仓开发
- 没有 `brief.md`，不允许进入影响分析

## 2. `impact-design-workflow`

用途：把业务意图变成结构化影响分析、轻量设计和执行状态。

执行顺序：

1. 填写 `impact.yaml`
2. 填写 `design.md`
3. 更新 `execution.yaml` 中的阶段、owner、依赖顺序和锁状态

核心文件：

- `impact.yaml`
- `design.md`
- `execution.yaml`

门禁：

- 没有 `impact.yaml`，不允许进入任务拆分和实现
- 同级规则冲突不得“猜一个执行”，必须写成 `待确认`

## 3. `task-splitting-workflow`

用途：把跨仓需求拆成可执行的 repo 级任务卡，并绑定执行边界。

执行顺序：

1. 生成 `tasks/*.md`
2. 为每个受影响仓绑定 `repo_owner`
3. 在 `execution.yaml` 中登记 `write_scopes`、`branch`、`worktree`

任务卡必须写清：

- 输入
- 输出
- 改动边界
- 禁止改动项
- 本仓验证命令
- 发布前证据项

## 4. `repo-execution-workflow`

用途：按仓边界进入实现和仓内自测。

执行顺序：

1. 读取本仓规则、命令契约、`execution.yaml`
2. 锁定目标 repo 的写边界
3. 按任务卡修改代码
4. 先跑本仓最小命令契约
5. 回填仓内验证结果和使用快照

要求：

- `backend-exec-agent` 只负责 `backend`
- `web-exec-agent` 只负责 `web-portal`
- `admin-web-exec-agent` 只负责 `admin-web`
- `mobile-a-exec-agent` 只负责 `mobile-a`
- `mobile-b-exec-agent` 只负责 `mobile-b`
- 当前阶段不默认把 `mobile-c`、`miniapp` 视为可发布工程
- 同一时间只允许一个 Agent 写一个业务仓
- 不允许多个 Agent 共享同一个可写 worktree

## 5. `cross-repo-acceptance-workflow`

用途：按用户业务链路做跨仓验收，而不是只看单仓绿灯。

执行顺序：

1. 以 `acceptance.md` 为唯一验收脚本
2. 逐步记录操作、预期结果和实际结果
3. 记录所依据的报告、分支、提交和环境快照
4. 把异常、缺口和风险写入 `verification/result.md`

要求：

- 只做单仓自测，不允许宣布跨端需求完成
- 验收单位必须是业务链路，不是某一个 repo
- `verification/result.md` 只允许 `verification-agent` 作为主 owner 写入

## 6. `release-governance-workflow`

用途：把“能跑”变成“可上线、可回滚、可观察”。

执行顺序：

1. 生成发布单
2. 汇总仓库、分支、配置、数据变更
3. 明确发布顺序
4. 明确回滚步骤
5. 明确发布后观察点

要求：

- 没有回滚说明，不允许形成发布结论
- 没有验收记录，不允许进入上线准备
- 所有外部事实必须带来源和时间戳
- 没有来源的 MCP 结论不能作为发布依据

## 7. `knowledge-feedback-workflow`

用途：把事故、返工和漏测项沉淀回控制平面。

执行顺序：

1. 在 `postmortem.md` 记录问题和根因
2. 把改进项回灌到规则、模板、回归集和 skills
3. 至少补一项：新规则 / 新模板 / 新回归 / 新技能
4. 更新控制仓文档与门禁

要求：

- 复盘不是可选动作
- 问题不能只留在聊天记录里

## 7. 人工审查与合并

人工审查重点：

- 需求是否被正确实现
- 风险是否被显式记录
- 验收和发布条件是否满足

人工不再替代结构化文档，也不接受“口头说已测过”。
