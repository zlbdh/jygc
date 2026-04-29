---
name: cross-repo-acceptance-recorder
description: 按业务链路记录示例产品跨仓验收步骤、实际结果、异常点和遗留风险，补全 `acceptance.md` 与 `verification/result.md`。Use when Codex needs to capture acceptance evidence for a multi-repo change rather than relying on single-repo build results.
---

# Cross Repo Acceptance Recorder

## Overview

把“已经联调过了”变成结构化验收记录，确保验收单位是业务链路，不是单仓通过。

## 执行步骤

1. 读取 `acceptance.md`、`impact.yaml`、`design.md` 和 `verification/result.md`。
2. 按用户流程逐步记录操作、预期结果、实际结果和异常点。
3. 优先覆盖审核流、状态同步、订单流、导出、幂等等关键链路。
4. 把遗留风险写进 `verification/result.md`，不要藏在聊天记录里。

## 输出要求

- 优先更新 `acceptance.md`
- 同步更新 `verification/result.md`
- 结论只基于实际执行证据
- 不因为单仓绿灯就宣布跨仓需求完成

## 校验清单

- 是否按业务链路记录
- 是否写明预期结果和实际结果
- 是否显式记录遗留风险
