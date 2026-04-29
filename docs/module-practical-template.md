# 《完整实战模板》

## 1. 使用方式

本模板用于指导“新增一个跨仓模块”时，控制仓和业务仓应该如何组织产物。  
示例模块：**新增服务人员排班与考勤模块**。

目标：

- 企业可为服务人员创建排班
- 服务人员可查看排班并签到/签退
- 异常打卡可发起申诉
- 企业可审批申诉
- 平台可查看监管数据

## 2. 示例目录结构

```text
changes/CHG-2026-0002-staff-scheduling-attendance/
  brief.md
  impact.yaml
  execution.yaml
  design.md
  acceptance.md
  tasks/
    backend.md
    web-portal.md
    admin-web.md
    mobile-a.md
    mobile-c.md
  verification/
    result.md
  postmortem.md
```

## 3. 示例 `brief.md`

```md
# CHG-2026-0002 - 新增服务人员排班与考勤模块

## 业务目标
- 企业可为服务人员创建排班
- 服务人员可查看排班并签到/签退
- 异常打卡可发起申诉
- 企业可审批异常申诉
- 平台可查看监管数据

## 用户角色
- 企业管理员
- 服务人员
- 平台监管人员

## 成功标准
- 企业后台可创建、编辑、停用排班
- 服务员端可查看个人排班并完成签到签退
- 考勤记录能回写后端并可查询
- 异常申诉能形成审批流
- 平台端可查看排班与异常统计

## 非目标
- 本期不做智能排班推荐
- 本期不做工资自动结算

## 风险说明
- 涉及跨端状态同步
- 涉及定位打卡与异常申诉
- 涉及平台端与企业端权限边界
```

## 4. 示例 `impact.yaml`

```yaml
change_id: "CHG-2026-0002-staff-scheduling-attendance"
title: "新增服务人员排班与考勤模块"
is_cross_repo: true
affected_repos:
  - id: backend
    modules: [schedule, attendance, appeal, approval]
  - id: web-portal
    modules: [schedule-admin, attendance-review]
  - id: admin-web
    modules: [attendance-supervision]
  - id: mobile-a
    modules: [attendance-approval-mobile]
  - id: mobile-c
    modules: [my-schedule, checkin-checkout, appeal]
affected_interfaces:
  - POST /schedule/create
  - POST /attendance/check-in
  - POST /attendance/check-out
  - POST /attendance/appeal
  - POST /attendance/appeal/approve
affected_tables:
  - schedule_plan
  - attendance_record
  - attendance_appeal
affected_configs:
  - geo-checkin-policy
dependency_order:
  - backend
  - web-portal
  - mobile-c
  - mobile-a
  - admin-web
notes:
  - "后端先行，前后端字段必须统一。"
```

## 5. 示例 `execution.yaml`

```yaml
change_id: "CHG-2026-0002-staff-scheduling-attendance"
title: "新增服务人员排班与考勤模块"
stage: planned
stage_owner: impact-design-agent
repo_owners:
  backend: backend-exec-agent
  web-portal: web-exec-agent
  admin-web: admin-web-exec-agent
  mobile-a: mobile-a-exec-agent
  mobile-c: mobile-c-planning-agent
write_scopes:
  control_repo:
    owner: impact-design-agent
    files:
      - brief.md
      - impact.yaml
      - execution.yaml
      - design.md
      - acceptance.md
      - verification/result.md
      - postmortem.md
  business_repos:
    backend: []
    web-portal: []
    admin-web: []
    mobile-a: []
    mobile-c: []
depends_on:
  - workspace-baseline-workflow
  - change-intake-workflow
branch:
  backend: "codex/CHG-2026-0002-hd-attendance"
  web-portal: "codex/CHG-2026-0002-qd-attendance"
  admin-web: "codex/CHG-2026-0002-admin-web-attendance"
  mobile-a: "codex/CHG-2026-0002-mobile-a-attendance"
  mobile-c: "codex/CHG-2026-0002-mobile-c-attendance"
worktree:
  backend: "D:\\workspace\\worktrees\\chg-0002-hd"
  web-portal: "D:\\workspace\\worktrees\\chg-0002-qd"
  admin-web: "D:\\workspace\\worktrees\\chg-0002-admin-web"
  mobile-a: "D:\\workspace\\worktrees\\chg-0002-mobile-a"
  mobile-c: "D:\\workspace\\worktrees\\chg-0002-mobile-c"
lock_state:
  control_repo: unlocked
  business_repos:
    backend: unlocked
    web-portal: unlocked
    admin-web: unlocked
    mobile-a: unlocked
    mobile-c: unlocked
snapshot_at: "2026-03-31T21:00:00+08:00"
```

## 6. 示例 `design.md`

```md
# CHG-2026-0002 设计说明

## 目标
- 新增服务人员排班与考勤模块

## 业务链路
- 企业创建排班
- 服务人员查看排班
- 服务人员签到/签退
- 系统记录考勤
- 异常时发起申诉
- 企业审批
- 平台查看监管数据

## 数据流 / 状态流
- 排班主数据在 backend
- 打卡记录主数据在 backend
- 审批状态主数据在 backend
- web-portal / mobile-a / mobile-c / admin-web 只消费或触发状态变化

## 接口与数据变更
- 排班接口
- 考勤接口
- 申诉与审批接口
- 排班、考勤、申诉相关表

## 跨仓依赖顺序
- backend
- web-portal
- mobile-c
- mobile-a
- admin-web

## 失败处理
- 重复签到要幂等
- 超范围定位要拒绝或进入异常申诉
- 审批失败不得丢失考勤留痕

## 兼容策略
- 第一阶段只新增，不替换现有工单体系

## 发布与回滚考虑
- 后端先发，前端与移动端后发

## 待确认
- 是否需要离线打卡补传
```

## 7. 示例任务卡

### 7.1 `tasks/backend.md`

```md
# CHG-2026-0002 / backend 任务卡

## 输入
- 排班、打卡、申诉、审批业务需求

## 输出
- 排班接口
- 签到签退接口
- 申诉与审批接口
- 表结构与状态流

## 改动边界
- 仅限排班/考勤/申诉相关模块

## 禁止改动项
- 不顺手改无关订单、商城、财务逻辑

## 本仓验证命令
- 构建：mvn package -DskipTests
- 测试：mvn test
- Smoke：mvn -Dtest=*Attendance* test
```

### 7.2 `tasks/web-portal.md`

```md
## 输出
- 排班管理页
- 考勤记录页
- 异常申诉审批页
```

### 7.3 `tasks/admin-web.md`

```md
## 输出
- 平台监管统计页
- 异常申诉查看页
```

### 7.4 `tasks/mobile-a.md`

```md
## 输出
- 企业移动端查看排班
- 企业移动审批异常打卡
```

### 7.5 `tasks/mobile-c.md`

```md
## 输出
- 我的排班页
- 签到/签退页
- 异常申诉页
```

## 8. 示例 `acceptance.md`

```md
# CHG-2026-0002 验收清单

1. 企业后台创建排班
   预期：排班创建成功，服务员端可见

2. 服务员查看排班
   预期：只看到本人排班，状态正确

3. 服务员签到
   预期：生成考勤记录，状态为已签到

4. 服务员异常申诉
   预期：生成申诉单，企业端待审批

5. 企业审批申诉
   预期：审批结果同步到服务员端和监管端

6. 平台查看监管数据
   预期：能看到排班、打卡、异常申诉统计
```

## 9. 示例 `verification/result.md`

```md
# CHG-2026-0002 验证结果

## 执行摘要
- 当前状态：待联调
- 快照来源：本地基线 + 仓内验证
- 快照时间：2026-03-31 21:00:00

## 仓内验证结果
| 仓库 | 执行命令 | 结果 | 备注 |
|------|----------|------|------|
| backend | mvn test | PASS | 排班与考勤相关测试通过 |
| web-portal | npm run build | PASS | 页面构建通过 |
| admin-web | npm run build | PASS | 平台监管页构建通过 |
| mobile-a | npm run lint | PASS | 企业端移动规则通过 |
| mobile-c | npm run lint | PASS | 原型仓已补齐基础工程 |

## 跨仓验收结果
| 步骤 | 验收项 | 结果 | 备注 |
|------|--------|------|------|
| 1 | 企业创建排班 | PASS | |
| 2 | 服务员查看排班 | PASS | |
| 3 | 服务员签到 | PASS | |
| 4 | 异常申诉 | PASS | |
| 5 | 企业审批 | PASS | |
| 6 | 平台监管查看 | PASS | |

## 遗留风险
- 定位异常场景仍需补边界测试
```

## 10. 示例发布顺序

推荐顺序：

1. `backend`
2. `admin-web`
3. `web-portal`
4. `mobile-a`
5. `mobile-c`

原因：

- 没有后端接口，前端和移动端先发没有意义
- 平台监管依赖后端状态
- 企业端和服务员端都依赖最终接口与状态流

## 11. 示例复盘回灌

如果上线后发现“服务员签到成功但企业端未同步显示”，复盘最少要做以下之一：

- 在控制仓补一条跨仓状态同步规则
- 在黄金回归集中新增“签到后企业端可见”用例
- 在 `postmortem.md` 写清根因和回灌动作
- 补一个专门检查同步字段的一次性 skill 或脚本

## 12. 使用建议

- 先复制本模板，再根据具体模块裁剪
- 不要把所有字段都留空后直接进业务仓开发
- 原型仓如果尚未工程化，先在 `impact.yaml` 和 `execution.yaml` 中显式标明“规划态”
