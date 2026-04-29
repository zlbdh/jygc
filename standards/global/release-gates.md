---
scope: release-governance
owner: harness-core
applies_to:
  - all-releases
precedence: 3
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# 发布门禁

## 1. 形成发布单前的最低条件

- 关联的业务仓 PR 已齐备
- 变更单已完成验收
- 配置、脚本、数据库影响已列出
- 回滚步骤可执行

## 2. 发布单必须包含

- 发布编号
- 关联 `change-id`
- 涉及仓库与分支/提交
- 数据库变更
- 配置变更
- 发布顺序
- 回滚步骤
- 发布后观察点

## 3. 禁止发布的情况

- 影响仓未全部验证
- 回滚步骤缺失
- 关键接口或关键页面未验收
- 只验证单仓未验证用户完整流程
- 外部事实没有来源或时间戳
