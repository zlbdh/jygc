---
name: rule-resolver
description: 为示例产品控制仓识别当前任务适用的规则层级、优先级和冲突点，并输出待确认项。Use when Codex needs to resolve which global, cross-repo, repo-local, module, or skill rules apply before implementation, review, or release.
---

# Rule Resolver

## Overview

把“这次到底听哪条规则”整理成可执行结论，避免 skill、仓规则和全局门禁互相打架。

## 执行步骤

1. 读取 `docs/rule-precedence.md`、`standards/`、目标业务仓规则和相关 `changes/<change-id>/` 文件。
2. 列出当前任务适用的规则，并按优先级排序。
3. 识别冲突：
   - 安全/环境规则与业务实现冲突
   - 跨仓门禁与 repo 习惯冲突
   - repo rule 与 skill 配方冲突
4. 输出冲突结论和待确认项；同级冲突必须建议写回 `impact.yaml` 或 `design.md`。

## 输出要求

- 优先输出“规则 -> 优先级 -> 适用原因 -> 处理结果”
- 不擅自让低优先级规则覆盖高优先级规则
- 对无法自动判断的情况标记 `待确认`
- 不直接批准发布

## 校验清单

- 是否按优先级排序
- 是否识别 skill 不能覆盖 repo rule
- 是否把同级冲突显式升级
