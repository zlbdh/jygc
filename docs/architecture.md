# 控制仓架构说明

## 1. 总体定位

`example-product-harness` 是示例产品多仓研发的控制平面，负责统一管理需求、任务、评测、验收和发布。

本仓不直接承载业务实现代码，而是通过结构化文档、脚本、skills 和 MCP 蓝图，把多个业务仓组织成一条可执行的研发流水线。

控制平面由 5 个组成部分构成：

- `docs/`：概念、架构、流程、清单
- `standards/`：门禁、治理和安全规则
- `templates/`：变更、设计、执行状态、验证、发布、复盘模板
- `.agent/skills/`：控制仓级流程型 skills
- `mcp/`：只读、非生产的 MCP 蓝图

## 2. 七个业务仓职责边界

### 2.1 `backend`：后端微服务仓

- 技术栈：Spring Cloud 示例工程、Spring Boot、Spring Cloud Alibaba、MyBatis Plus
- 职责：承载订单、商城、财务、物业、养老、培训等后端业务能力
- 关键特征：多微服务、Redis、RabbitMQ、Seata、导出、幂等、权限体系

### 2.2 `web-portal`：企业平台 PC 端

- 技术栈：Vue 3、Vite、Element Plus、Pinia
- 职责：企业管理员与业务操作人员的后台管理界面
- 关键特征：工单调度、商城、财务、智慧物业、养老、培训中心、系统管理

### 2.3 `admin-web`：示例产品大平台管理端

- 技术栈：按现有需求文档暂按 Vue 3 + Vite + Element Plus 基线管理
- 职责：平台级企业审核、服务/商品审核、订单路由、平台消费者运营、全局监管
- 关键特征：不是企业后台，而是平台总控端

### 2.4 `mobile-a`：企业端移动 App

- 技术栈：React Native、Expo、TypeScript
- 职责：企业管理者、运营和一线人员的移动管理工具
- 关键特征：待办、订单、客户、员工、审批、移动化业务视图

### 2.5 `mobile-b`：商家端移动 App

- 技术栈：按现有需求文档暂按 React Native + TypeScript 基线管理
- 职责：入驻商家移动经营、商品发布、订单处理、经营分析
- 关键特征：店铺管理、商品管理、商家订单与结算

### 2.6 `mobile-c`：服务员端移动 App

- 技术栈：按现有需求文档暂按 React Native + TypeScript 基线管理
- 职责：一线服务人员接单、排班、打卡、收入查看
- 关键特征：工单执行、考勤、收入透明、消息通知

### 2.7 `miniapp`：消费者小程序

- 技术栈：按现有需求文档暂按小程序工程 + TypeScript/Node 辅助工具链管理
- 职责：消费者轻量化服务入口
- 关键特征：小程序配置、平台与企业双模式、微信生态能力

## 3. 控制仓负责什么

- 统一定义 `change-id`
- 记录跨仓影响分析
- 记录执行状态、owner、锁和 worktree
- 输出 repo 级任务卡
- 管理黄金回归用例
- 汇总发布清单与回滚说明
- 固化 AI 执行规则与人工审查门禁
- 设计并托管 Agent / Workflow / Skill / MCP 控制平面
- 管理 7 仓本地拉齐、自检和风险矩阵

## 4. 控制仓不负责什么

- 不替代业务仓 README
- 不存放业务仓主代码
- 不绕过业务仓本地验证
- 不用自然语言聊天记录替代结构化文档

## 5. 仓间协作模型

```text
需求进入控制仓
  -> clone/sync/discover/baseline
  -> brief.md
  -> impact.yaml
  -> execution.yaml
  -> tasks/<repo>.md
  -> 各业务仓执行开发与自测
  -> 控制仓做跨端验收
  -> release/*.md 输出发布说明
```

## 6. 控制仓目录与职责映射

- `repos/`：业务仓元数据与定位
- `docs/`：全局架构、概念、流程、命令契约、清单
- `standards/`：通用规则与分端规则
- `templates/`：标准模板
- `changes/`：单个需求的全过程档案
- `evals/`：黄金回归集和自动化入口规划
- `reports/`：本地拉齐、自检、契约发现和基线验证报告
- `release/`：发布包与回滚说明
- `.agent/skills/`：控制仓级流程型 skills
- `mcp/`：MCP 蓝图与接入策略
- `scripts/`：初始化、校验和工作区检查脚本
- `docs/cross-repo/`：跨仓长期索引
