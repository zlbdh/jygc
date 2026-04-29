---
name: task-card-generator
description: 为示例产品控制仓按仓拆分任务卡，生成或完善 `tasks/*.md` 中的输入、输出、边界、禁改项和验证命令。Use when Codex needs to turn an approved `impact.yaml` and design into executable repo-level task cards for backend, web, mobile, or governance work.
---

# Task Card Generator

## Overview

把跨仓需求拆成 repo 级执行单元，让不同仓的实现边界和验证方式清晰可见。

## 执行步骤

1. 读取 `impact.yaml`、`design.md`、`repos/repos.yaml` 和目标 `tasks/` 目录。
2. 只为受影响仓补全任务卡内容；不受影响仓保留占位或注明不涉及。
3. 明确输入、输出、改动边界、禁止改动项和本仓验证命令。
4. 把发布前需要的证据项提前写进任务卡。

## 输出要求

- 默认更新 `tasks/<repo-id>.md`
- 每张任务卡只描述一个仓
- 优先使用 `repos.yaml` 中登记的命令契约
- 不直接给出跨仓验收结论

## 校验清单

- 是否按仓拆分而不是按人拆分
- 是否明确边界和禁改项
- 是否附带验证命令
- 是否体现依赖顺序
