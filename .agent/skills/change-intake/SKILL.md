---
name: change-intake
description: 将模糊需求、bug、返工或事故修复整理成示例产品控制仓标准变更单入口。Use when Codex needs to create or refine `changes/CHANGE_ID/brief.md`, extract business goal, user roles, success criteria, non-goals, risks, and background before cross-repo impact analysis begins.
---

# Change Intake

## Overview

把原始需求整理成控制仓可继续流转的 `brief.md`，为后续 `impact.yaml`、任务卡和发布治理提供稳定输入。

## 执行步骤

1. 读取 `repos/repos.yaml`、`docs/harness-engineering.md`、`docs/workflow.md` 和目标 `changes/<change-id>/`。
2. 提炼业务目标、用户角色、成功标准、非目标、风险说明和关联背景。
3. 优先产出可执行、可验证的成功标准，不写空泛目标。
4. 如果信息不足，保留最小必要的 `待确认`，不要擅自扩写业务细节。

## 输出要求

- 只产出或更新 `brief.md`
- 默认使用中文
- 成功标准必须可检验
- 不直接生成发布结论

## 校验清单

- 需求目标是否明确
- 用户角色是否具体
- 成功标准是否可验证
- 非目标是否防止范围失控
- 风险是否显式记录
