# 业务链路索引

## 1. 企业入驻与平台审核链路

- 主链路：`web-portal / mobile-a -> backend -> admin-web -> backend -> web-portal / mobile-a`
- 关键事实：
  - 平台端 `admin-web` 负责审核动作
  - 后端 `backend` 负责状态持久化与分发
  - 企业侧 `web-portal / mobile-a` 负责结果展示与后续运营

## 2. 商品 / 服务上架与审核链路

- 主链路：`web-portal / mobile-b -> backend -> admin-web -> backend -> web-portal / mobile-b / miniapp`
- 关键事实：
  - 审核动作在平台端
  - 业务状态以后端为主
  - 消费者入口最终由 `miniapp` 承接，但当前仍是原型仓

## 3. 订单路由与服务执行链路

- 主链路：`miniapp / web-portal / mobile-b -> backend -> admin-web -> backend -> mobile-a / mobile-b / mobile-c`
- 关键事实：
  - 订单和工单状态以 `backend` 为主
  - 平台端负责全局监管和部分路由
  - 服务执行最终会延伸到 `mobile-c`，但当前工程未成型

## 4. 审批、待办与消息同步链路

- 主链路：`web-portal / admin-web -> backend -> mobile-a / mobile-b / mobile-c`
- 关键事实：
  - 后端是待办、消息、状态同步的主出口
  - 移动端只消费和回写对应动作

## 5. 退款、账单、导出链路

- 主链路：`web-portal / admin-web / mobile-a / mobile-b -> backend`
- 关键事实：
  - 财务、导出、幂等和审计要求集中在 `backend`
  - 前端与移动端主要负责查询、操作触发和结果展示
