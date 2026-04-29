# api-contract-readonly

## 目标

统一暴露 `backend` 与各端协作所需的接口契约、字段说明和样例。

## 允许能力

- 读取 OpenAPI / Postman / JSON Schema
- 查看请求参数、响应字段、错误码
- 查看接口样例

## 禁止能力

- 发起写操作接口调用
- 修改接口定义
- 连接生产网关

## 适用场景

- 生成 `brief.md` 和 `impact.yaml`
- 拆 `web-portal / admin-web / mobile-a / mobile-b` 任务卡
- 对照接口契约做跨仓验收
