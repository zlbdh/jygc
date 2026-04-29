---
name: postmortem-to-regression
description: 把示例产品的事故、返工、漏测和复盘记录转成规则更新、模板更新、回归用例和 skill 改进候选。Use when Codex needs to turn a `postmortem.md` or failed verification history into concrete knowledge feedback artifacts.
---

# Postmortem To Regression

## Overview

把“这次出过的问题”转成下次能自动挡住的问题，避免复盘只停留在文字总结。

## 执行步骤

1. 读取 `postmortem.md`、`verification/result.md`、`acceptance.md`、相关基线报告和规则文档。
2. 提炼问题类型：
   - 规则缺失
   - 模板缺失
   - 回归缺失
   - skill 缺失
3. 至少输出一个可落地回灌项，并指向具体文件或目录。
4. 如果问题只属于某一仓，标明应回灌到控制仓还是业务仓。

## 输出要求

- 输出“问题 -> 根因 -> 回灌位置 -> 下一步动作”
- 至少给出一个回归或规则更新候选
- 不把复盘停留在抽象结论
- 不直接跳过人工确认就修改发布结论

## 校验清单

- 是否把问题转成具体产物
- 是否指出回灌到哪一层
- 是否避免只做经验复述
