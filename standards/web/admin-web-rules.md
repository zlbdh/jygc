---
scope: repo
owner: admin-web-owner
applies_to:
  - admin-web
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `admin-web` 大平台管理端规则

## 1. 适用范围

本规则适用于 `example-product-admin-web`。

## 2. 当前前提

基于现有需求文档，`admin-web` 暂按以下基线治理：

- Vue 3
- Vite
- Element Plus
- 平台总控视角

本规则是首版占位规则，待本地仓落位后需要用真实代码结构再收敛一次。

## 3. 业务边界

`admin-web` 处理的是平台级能力，不是企业自管后台。设计时必须显式区分：

- 企业审核
- 服务/商品审核
- 订单路由与监管
- 平台消费者运营
- 平台级统计与结算

## 4. 实现原则

- 平台端字段、菜单、状态名要与企业端区分
- 所有“平台 -> 企业”的同步点必须在变更单中显式记录
- 平台端页面优先服务监管、审核和路由，不复用企业端语义

## 5. 最小验证要求

- `npm run build`
- 关键审核流和同步流进入黄金回归集

## 6. 待确认项

- 真实脚本名称
- 真实目录结构
- lint / typecheck 命令
