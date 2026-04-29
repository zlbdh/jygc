---
name: cross-repo-impact
description: 为示例产品多仓需求生成和校正 `impact.yaml`，识别受影响仓、模块、接口、表、配置和依赖顺序。Use when Codex needs to analyze whether a change touches `backend / web-portal / admin-web / mobile-a / mobile-b / mobile-c / miniapp` and produce a structured cross-repo impact record before implementation.
---

# Cross Repo Impact

## Overview

把需求从“感觉会影响几个仓”整理成结构化 `impact.yaml`，并在需要时补充轻量设计要点。

## 执行步骤

1. 读取 `brief.md`、`repos/repos.yaml`、`docs/architecture.md`、`docs/command-contract.md`。
2. 判断影响的仓、模块、接口、表、配置和依赖顺序。
3. 优先标出跨端状态同步、审核流、订单流、导出、幂等等高风险联动点。
4. 如果需要，补一版轻量 `design.md` 草稿，但不要跳过 `impact.yaml`。

## 输出要求

- 优先更新 `impact.yaml`
- 必须明确 `affected_repos` 和 `dependency_order`
- 对不确定项使用 `待确认`，不要伪造事实
- 不直接改业务仓代码

## 校验清单

- 是否覆盖所有受影响仓
- 是否写明接口和配置影响
- 是否识别发布顺序依赖
- 是否显式记录跨端风险
