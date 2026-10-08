---
scope: repo
owner: backend-owner
applies_to:
  - backend
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `backend` Backend rules

## 1. Scope

These rules apply to `example-product-backend`.

## 2. Technical baseline

- Spring Cloud example project
- Spring Boot + Spring Cloud Alibaba
- MyBatis Plus
- Redis / RabbitMQ / Seata

## 3. Structural constraints

Follow the existing layers:

- `controller`
- `service`
- `mapper`
- `xml`
- `domain/dto/vo`

## 4. Business implementation considerations

- Explicitly handle idempotency in critical state flows such as orders, payments, refunds, and approvals
- Prefer the existing `/export/url` direct-link pattern for exports
- Evaluate whether Seata is needed for cross-service strong consistency
- Message-queue consumers must include idempotency and failure handling

## 5. Minimum verification requirements

- Run at least a Maven build or test for the target module
- Add API smoke tests or targeted unit tests for interface changes
- Compilation alone is insufficient for exports, idempotency, message queues, or state-flow changes

## 6. Documentation writeback requirements

Write the following changes back to the control repository:

- New interfaces
- New database tables or fields
- State-flow changes
- Key middleware decisions
