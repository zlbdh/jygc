# 七仓最小命令契约

本文件定义控制仓在编排 AI 和 CI 时可依赖的最小命令接口。业务仓后续可以扩展，但不能少于这里的基线。

## 1. 契约原则

- 优先定义“最小可执行命令”
- 先保证可运行，再逐步补齐 lint、typecheck、smoke
- 命令名以业务仓真实脚本为准，本文件负责统一说明

## 2. `backend` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `mvn -version` | 用于检查本机 Maven 可用性 |
| 构建 | `mvn -pl <module> -am package -DskipTests` | 按目标微服务或模块执行 |
| 测试 | `mvn -pl <module> -am test` | 至少支持模块级测试 |
| Smoke | `mvn -pl <module> -am -Dtest=*Test test` | 当前作为占位基线 |

说明：

- `backend` 是多模块 Maven 工程，执行时必须指定目标模块
- 导出、幂等、MQ、Seata 相关改动应补针对性测试

## 3. `web-portal` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `npm ci --ignore-scripts` | 只做安全安装准备，并尽量避免改写 lockfile |
| 构建 | `npm run build:prod` | 当前已知可用基线 |
| 测试 | `npm run build:stage` | 首版用构建代替最低验证 |
| Smoke | `npx playwright test` | 当前为控制仓规划入口 |

后续待补：

- `npm run lint`
- `npm run typecheck`

## 4. `admin-web` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `npm ci --ignore-scripts` | 只做安全安装准备，并尽量避免改写 lockfile |
| 构建 | `npm run build:prod` | 已在本地仓确认 |
| 测试 | `npm run build:stage` | 首版以 staging 构建代替最低验证 |
| Smoke | `npx playwright test` | 控制仓规划入口 |

当前状态：`baseline-ready`

后续待补：

- `lint`
- `typecheck`

## 5. `mobile-a` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `npm ci --ignore-scripts` | 首版最低准备命令，并尽量避免改写 lockfile |
| 构建 | `npm run start` | 用于验证 React Native CLI 可用性，不作为联调启动命令 |
| 测试 | `npm run test -- --watch=false` | 当前已确认可用 |
| 校验 | `npm run lint` | 首版以 lint 代替 typecheck |
| Smoke | `maestro test .\\evals\\mobile` | 控制仓规划入口 |

当前状态：`baseline-ready`

## 6. `mobile-b` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `npm ci --ignore-scripts` | 首版最低准备命令，并尽量避免改写 lockfile |
| 构建 | `npm run start` | 用于验证 React Native CLI 可用性，不作为联调启动命令 |
| 测试 | `npm run test -- --watch=false` | 当前已确认可用 |
| 校验 | `npm run lint` | 首版以 lint 代替 typecheck |
| Smoke | `maestro test .\\evals\\mobile` | 控制仓规划入口 |

当前状态：`baseline-ready`

## 7. `mobile-c` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `npm install --ignore-scripts` | 首版最低准备命令 |
| 测试 | `npm run typecheck` | 占位基线，待本地仓确认 |
| Smoke | `maestro test .\\evals\\mobile` | 控制仓规划入口 |

当前状态：`missing-contract`

说明：

- 当前仓只有需求文档和 README，尚未形成可执行工程
- 进入本地基线前需要先补齐真实 App 工程结构

## 8. `miniapp` 命令契约

| 类型 | 最小命令 | 说明 |
|------|----------|------|
| 引导 | `npm install --ignore-scripts` | 如仓库使用 Node 工具链 |
| 构建 | `npm run build` | 占位基线，待本地仓确认 |
| 测试 | `npm run lint` | 占位基线 |
| Smoke | `微信开发者工具导入检查` | 首版以环境和工程配置检查为主 |

当前状态：`missing-contract`

说明：

- 当前仓以 HTML 页面原型和生成脚本为主
- 进入小程序本地基线前需要先补齐标准小程序工程配置

## 9. 本地验证分层

- `L1`：拉齐检查，验证克隆、远端、分支、工作区、manifest
- `L2`：安全自检，只运行无副作用或低风险的本地命令
- `L3`：本地联调，第一阶段暂不纳入控制仓门禁

## 10. 契约落地规则

- `repos/repos.yaml` 与本文件必须保持一致
- 业务仓若命令发生变化，必须同步更新本文件和 `repos.yaml`
- 控制仓不允许调用未登记命令作为正式门禁
- `missing-contract` 仓必须先补契约，再谈本地联调与生产前置验证
