---
scope: review
owner: harness-core
applies_to:
  - all-changes
precedence: 3
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# 人工审查门禁

人工审查关注的是结果、风险和可发布性，而不是替代 AI 做结构化整理。

## 必过项

- 变更单结构完整
- 影响分析明确
- `execution.yaml` 结构完整且 owner 边界明确
- 任务卡与实际改动仓一致
- 本仓最小验证结果已记录
- 跨端验收结果已回填
- 风险与回滚说明已写清

## 重点审查问题

- 需求边界是否被实现错位
- 是否存在跨仓漏改
- 是否存在发布顺序依赖未显式标注
- 是否存在破坏现网流程的风险
- 是否把临时假设错误地写成长期规则
