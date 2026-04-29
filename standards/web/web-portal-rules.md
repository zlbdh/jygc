---
scope: repo
owner: web-owner
applies_to:
  - web-portal
precedence: 4
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# `web-portal` 企业平台前端规则

## 1. 适用范围

本规则适用于 `example-product-web-portal`。

## 2. 技术基线

- Vue 3
- Vite
- Element Plus
- Pinia
- Axios

## 3. 页面实现原则

- 新页面优先复用既有管理后台交互模式
- 列表、表单、详情页遵循既有管理后台交互模式和目录组织
- 导出统一优先走 `exportAndPreview` 直链模式

## 4. 改动注意点

- 页面权限、按钮权限、菜单权限要同步考虑
- 列表页要明确搜索条件、分页和空态
- 表单字段要与后端校验规则保持一致
- 如果涉及大平台/企业平台联动，要在控制仓写清楚状态同步点

## 5. 最小验证要求

- `npm run build:prod`
- 关键流程进入黄金回归集

## 6. 后续待补

- `lint`
- `typecheck`
- Playwright 自动化用例与真实页面映射
