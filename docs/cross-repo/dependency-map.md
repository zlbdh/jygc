# 仓间依赖图

## 1. 仓库角色

- `backend`：后端主业务与状态事实源
- `web-portal`：企业平台 PC 端
- `admin-web`：平台总控端
- `mobile-a`：企业端移动 App
- `mobile-b`：商家端 App
- `mobile-c`：服务员端 App，当前按原型仓治理
- `miniapp`：消费者小程序，当前按原型仓治理

## 2. 主依赖关系

```text
web-portal ----\
admin-web ---\
mobile-a ---\
mobile-b ----> backend
mobile-c ---/
miniapp -----/
```

说明：

- 当前大多数跨仓状态的主事实源是 `backend`
- `admin-web` 负责平台级审核、监管、路由与总控
- `web-portal`、`mobile-a`、`mobile-b` 主要消费和操作业务能力
- `mobile-c`、`miniapp` 的业务角色已明确，但工程仍未成型

## 3. 当前阶段不变量

- 跨仓状态流转必须能在 `backend` 找到落点
- 平台审核类链路必须显式经过 `admin-web`
- 移动端和前端展示不能替代后端状态事实
- 原型仓不应被当成可发布仓
