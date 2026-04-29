---
scope: control-plane
owner: harness-core
applies_to:
  - backend
  - web-portal
  - admin-web
  - mobile-a
  - mobile-b
  - mobile-c
  - miniapp
precedence: 3
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# Agent 治理规则

## 1. 角色边界

- `change-intake-agent` 只负责需求受理和 `brief.md`
- `impact-design-agent` 只负责影响分析、设计说明、依赖顺序和阶段级 `execution.yaml`
- `backend-exec-agent` 只负责 `backend`
- `web-exec-agent` 只负责 `web-portal`
- `admin-web-exec-agent` 只负责 `admin-web`
- `mobile-a-exec-agent` 只负责 `mobile-a`
- `mobile-b-exec-agent` 只负责 `mobile-b`
- `mobile-c-planning-agent` 只负责 `mobile-c` 的规划与工程补齐前分析
- `miniapp-planning-agent` 只负责 `miniapp` 的规划与工程补齐前分析
- `verification-agent` 只负责验证、报告和验收记录
- `release-agent` 只负责发布单、回滚单和观察点
- `knowledge-agent` 只负责复盘和回灌

## 2. 写权限与锁

- `brief.md` 默认由 `change-intake-agent` 持有主写权限
- `impact.yaml`、`design.md`、阶段级 `execution.yaml` 默认由 `impact-design-agent` 持有主写权限
- `tasks/<repo>.md` 默认由 `task-card-generator` 或对应 repo owner 持有主写权限
- `verification/result.md` 默认由 `verification-agent` 持有主写权限
- 发布单默认由 `release-agent` 持有主写权限
- 同一时间只允许一个 Agent 写一个控制仓主产物
- 同一时间只允许一个 Agent 写一个业务仓
- 每个执行 Agent 必须使用独立 branch / worktree

## 3. 禁止行为

- 不允许没有 `change-id` 直接开工
- 不允许跳过 `impact.yaml` 进入跨仓开发
- 不允许跳过 `execution.yaml` 直接并发分派执行 Agent
- 不允许一个 Agent 跨越多个执行边界随意改仓
- 不允许多个 Agent 共享同一个可写 worktree
- 不允许把发布结论建立在单仓自测之上
- 不允许默认访问生产环境

## 4. 协作原则

- 任务先按仓边界拆，再分配给 Agent
- Agent 输出必须回填到控制仓结构化文件
- 所有结论都要附带快照来源：报告、分支、提交、环境或时间戳
- 人工审查只对正确性、风险和发布条件负责
- Agent 不替代负责人做业务裁决

## 5. 冲突处理

- 多个 Agent 可同时读同一 skill、同一规则和同一只读 MCP
- 如果两个 Agent 需要同写同一产物，第二个只能读或以评审意见附加，不能并写主文件
- 同级规则冲突不得猜测执行，必须写入 `impact.yaml` 或 `design.md` 的 `待确认`
- 原型仓 `mobile-c`、`miniapp` 当前不进入正式执行 Agent 池

## 6. 当前阶段默认模式

- AI 主执行
- 人审合并
- 控制仓是唯一入口
