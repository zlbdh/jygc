---
scope: repo
owner: mobile-a-owner
applies_to:
  - mobile-a
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `mobile-a` 企业端 App 规则

## 1. 适用范围

本规则适用于 `example-product-mobile-a`。

## 2. 技术基线

- React Native
- Expo
- TypeScript
- React Navigation

## 3. 业务定位

企业端 App 是企业平台的移动延伸，不是消费者端。

优先承载：

- 待办
- 订单与工单概览
- 客户与员工相关管理
- 审批与通知

## 4. 实现原则

- 页面状态、接口字段优先与企业平台和后端保持一致
- 不在页面内长期保留大量临时 Mock 逻辑
- 重要数据通过显式的 service / api 封装对接
- 待办和消息类链路要优先纳入回归用例

## 5. 最小验证要求

- `npm install`
- `npm run typecheck`（待本地仓确认）
- 关键流程预留 Maestro smoke 入口

## 6. 当前限制

本仓首版只固化规则，不假设 `mobile-a` 当前已在本机完整落位。后续需要在真实仓到位后补充：

- 导航结构映射
- 真实命令契约
- 移动端 smoke 脚本
