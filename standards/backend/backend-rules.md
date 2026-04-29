---
scope: repo
owner: backend-owner
applies_to:
  - backend
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `backend` 后端规则

## 1. 适用范围

本规则适用于 `example-product-backend`。

## 2. 技术基线

- Spring Cloud 示例工程
- Spring Boot + Spring Cloud Alibaba
- MyBatis Plus
- Redis / RabbitMQ / Seata

## 3. 结构约束

优先遵循既有分层：

- `controller`
- `service`
- `mapper`
- `xml`
- `domain/dto/vo`

## 4. 业务实现关注点

- 订单、支付、退款、审核等关键状态流要显式处理幂等
- 导出优先复用现有 `/export/url` 直链模式
- 跨服务强一致场景要判断是否需要 Seata
- MQ 消费逻辑要带幂等与失败处理

## 5. 最小验证要求

- 至少跑目标模块级 Maven 构建或测试
- 涉及接口变更时，补接口 smoke 或针对性单测
- 涉及导出、幂等、MQ、状态流时，不能只跑编译

## 6. 文档回填要求

以下情况必须回填到控制仓：

- 新增接口
- 新增数据库表或字段
- 状态流变化
- 关键中间件决策
