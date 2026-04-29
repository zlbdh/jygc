# {{CHANGE_ID}} / {{REPO_ID}} 任务卡

## 仓库信息

- 仓库：`{{REPO_NAME}}`
- 仓库 ID：`{{REPO_ID}}`
- 技术栈：`{{STACK}}`
- 默认执行 Agent：`{{DEFAULT_OWNER}}`

## 执行状态引用

- 分支：在 `execution.yaml` 中登记
- worktree：在 `execution.yaml` 中登记
- 锁状态：在 `execution.yaml` 中登记
- 真实写代码任务必须使用独立且干净的 worktree，不得直接在主仓脏工作树执行

## 输入

- 

## 输出

- 

## 改动边界

- 

## 禁止改动项

- 

## 本仓验证命令

- 构建：
- 测试：
- Smoke：

## 回填要求

- repo worker 只回填 `verification/workers/{{REPO_ID}}.md`
- 不直接修改 `verification/result.md`
- 主验证结论由 `verification-agent` 汇总写入 `verification/result.md`
