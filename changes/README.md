# 变更单目录说明

所有需求都必须以 `changes/<change-id>/` 的形式归档。

标准结构如下：

```text
changes/CHG-2026-xxxx-<slug>/
  brief.md
  impact.yaml
  execution.yaml
  design.md
  acceptance.md
  tasks/
    <repo-id>.md
  verification/
    result.md
  postmortem.md
```

说明：

- `brief.md`：业务目标、范围与成功标准
- `impact.yaml`：跨仓影响分析唯一结构化入口
- `execution.yaml`：机器可读的执行状态、owner、写边界、worktree 和锁信息
- `design.md`：设计决策与依赖顺序
- `acceptance.md`：用户流程验收清单
- `tasks/`：repo 级任务卡，默认会按 `repos.yaml` 中的仓库列表自动生成
- `verification/result.md`：验证结果、失败项与遗留风险
- `postmortem.md`：发布后复盘与回灌记录

当前控制仓默认支持的第一阶段范围是示例产品 7 仓，因此新建变更单时会自动生成以下任务卡：

- `backend.md`
- `web-portal.md`
- `admin-web.md`
- `mobile-a.md`
- `mobile-b.md`
- `mobile-c.md`
- `miniapp.md`
