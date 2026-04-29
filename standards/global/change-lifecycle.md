---
scope: control-plane
owner: harness-core
applies_to:
  - all-changes
precedence: 2
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# 变更生命周期

每个变更单按以下状态推进：

1. `draft`
   - 只有基本背景，还未完成影响分析
2. `analyzing`
   - 正在补 `impact.yaml`、`design.md` 和 `execution.yaml`
3. `planned`
   - 任务卡已拆完，可以进入各仓执行
4. `implementing`
   - 至少一个业务仓已开工
5. `verifying`
   - 各仓自测完成，正在做跨端验收
6. `ready-for-review`
   - 已形成发布结论，等待人工审查
7. `released`
   - 已发布并完成记录
8. `closed`
   - 复盘完成，生命周期结束

## 状态推进规则

- 没有 `impact.yaml`，不能从 `draft` 进入 `planned`
- 没有 `execution.yaml`，不能从 `draft` 进入 `planned`
- 没有任务卡，不能从 `analyzing` 进入 `planned`
- 没有验收结果，不能进入 `ready-for-review`
- 没有发布或放弃结论，不能 `closed`
