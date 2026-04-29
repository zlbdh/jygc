---
name: release-package-generator
description: 为示例产品控制仓汇总发布顺序、回滚步骤、配置变更、观察点和风险摘要，生成结构化发布单。Use when Codex needs to prepare `release-note` style output after verification and acceptance are complete, but before human approval and actual deployment.
---

# Release Package Generator

## Overview

把“可以发了”的口头判断整理成结构化发布单和回滚清单，供人工审查与上线准备使用。

## 执行步骤

1. 读取 `verification/result.md`、`acceptance.md`、`impact.yaml` 和 `standards/global/release-gates.md`。
2. 汇总涉及仓库、分支、配置、数据变更、发布顺序和回滚步骤。
3. 明确发布后观察点和风险摘要。
4. 发现缺验收、缺回滚、缺验证时，直接标记不能形成发布结论。

## 输出要求

- 默认更新发布单模板
- 只做发布准备，不直接批准上线
- 必须显式写出回滚步骤和观察点
- 不跳过发布门禁

## 校验清单

- 是否列出涉及仓库和顺序
- 是否有数据库与配置变更
- 是否有回滚步骤
- 是否有发布后观察点
