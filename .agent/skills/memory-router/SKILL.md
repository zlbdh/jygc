---
name: memory-router
description: 为示例产品控制仓确定当前任务应该先读取哪些事实源、哪些属于长期记忆、哪些只是短期上下文，并输出缺口与写回要求。Use when Codex needs to decide what to read first across `docs/`, `standards/`, `changes/`, business-repo rules, reports, and MCP blueprints before implementation or review.
---

# Memory Router

## Overview

把“我该先看什么”变成结构化路由，而不是靠临时感觉找上下文。

## 执行步骤

1. 读取 `AGENTS.md`、`docs/memory-governance.md`、`docs/rule-precedence.md` 和目标 `changes/<change-id>/`。
2. 判断当前任务需要哪些层的记忆：
   - 全局记忆
   - 跨仓记忆
   - 变更记忆
   - 仓 / 模块记忆
   - 验证记忆
   - 外部上下文
3. 输出推荐读取顺序、事实源清单、已知缺口和必须写回的文件。
4. 对没有来源或已过时的信息，明确标为“线索”而不是“事实”。

## 输出要求

- 优先输出“记忆层 -> 路径 -> 用途”
- 明确区分事实、假设、待确认
- 说明哪些结论必须写回控制仓
- 不直接修改业务仓代码

## 校验清单

- 是否区分长期记忆和短期记忆
- 是否识别必须写回的结构化产物
- 是否避免把聊天记录当作系统事实
