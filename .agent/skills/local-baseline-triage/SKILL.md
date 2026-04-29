---
name: local-baseline-triage
description: 读取示例产品控制仓的本地基线、契约发现和工作区检查报告，提炼仓库状态、主要失败点和下一步动作。Use when Codex needs to interpret `reports/local-validation/*` outputs and produce concise repo-by-repo diagnosis before implementation or release decisions.
---

# Local Baseline Triage

## Overview

把大量终端输出和报告压缩成可执行结论，明确哪些仓可继续、哪些仓必须先修。

## 执行步骤

1. 读取最新 `reports/local-validation/` 下的 summary、matrix 和 contracts 报告。
2. 按仓给出状态、失败点、优先级和下一步动作。
3. 先区分历史问题、环境问题、契约缺口和真实代码质量问题。
4. 优先提炼第一信号，不把整段日志原样灌进结论。

## 输出要求

- 优先输出“仓库 -> 状态 -> 原因 -> 下一步”
- 默认使用中文
- 不直接修改代码
- 不把 `L1/L2` 报告误读成业务验收结论

## 校验清单

- 是否区分环境问题和代码问题
- 是否给出可执行下一步
- 是否避免冗长日志复述
