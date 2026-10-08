# Mapping Official Harness Engineering Guidance to the Example Product

## 1. Purpose

This document answers three questions:

1. What are the core ideas in publicly available official harness engineering guidance?
2. How far has the example product progressed?
3. How can no-hand-code business development become practical in the current project?

It describes the current local no-hand-code V1 implementation and does not replace the main handbook.

## 2. Core ideas in official harness engineering guidance

The public guidance places the model inside an engineering system that can operate continuously. Five capabilities summarize the approach:

1. Repositories and documentation are sources of truth.
2. Persistent threads/runtimes are available.
3. Agents actually read code, run tools, inspect results, and iterate on fixes.
4. Agents can observe interfaces, logs, metrics, and traces.
5. Agents can review one another's work, while people primarily steer and approve.

For the example product, these ideas must become concrete engineering structures in the control repository.

## 3. Mapping to the current example product

### 3.1 Repository knowledge / system of record

Official concept:

- Repository documentation, plans, constraints, and rules are sources of truth.

Current mapping:

- The control repository is the authoritative entry point.
- Every request first enters `changes/<change-id>/`.
- Business repositories no longer serve as direct request-intake points.

Corresponding files:

- `repos/repos.yaml`
- `docs/workflow.md`
- `docs/memory-governance.md`
- `docs/rule-precedence.md`
- `changes/<change-id>/*`

### 3.2 Thread / runtime

Official concept:

- Persistent App Server, thread manager, and core threads.

Current mapping:

- V1 does not implement a complete App Server yet.
- `execution.yaml + agent-registry + dispatcher + worker/review packet` provides a local substitute for the thread layer.

Corresponding files:

- `config/agent-registry.yaml`
- `templates/execution.yaml`
- `scripts/orchestrator/dispatch-change.ps1`
- `scripts/orchestrator/run-role.ps1`
- `scripts/orchestrator/review-worker-output.ps1`

### 3.3 Tool execution loop

Official concept:

- Agents read code, edit code, run commands, and fix problems iteratively.

Current mapping:

- Repository workers execute in isolated worktrees.
- Workers use the task card and write scope as their inputs.
- Workers modify only permitted paths.
- Workers run minimum repository verification commands.

Corresponding files:

- `verification/workers/*.md`
- `runtime/worker-responses/*.json`
- `runtime/review-results/*.json`

### 3.4 Observability

Official concept:

- Agents can inspect interfaces, logs, metrics, traces, schemas, and configuration.

Current mapping:

- V1 does not yet integrate live MCP.
- Current observability sources are:
  - Code
  - Git diff
  - Command output
  - Baseline reports
  - Worker results
  - Review packets

Current status:

- `mcp/` contains blueprints only.
- Read-only schema, configuration, and observability MCP services are not integrated yet.

### 3.5 Agent-to-agent review

Official concept:

- Worker self-review followed by a reviewer agent's second review.

Current mapping:

- Repository workers do not write the primary conclusion.
- Review workers read diffs, worker results, task cards, and consistency constraints.
- `verification-agent` consolidates conclusions in `verification/result.md`.

## 4. Existing capabilities

The project already has:

1. A control plane
2. Local baseline gates
3. Change record modeling
4. A role registry
5. A dispatcher
6. Repository worker packets
7. Review packets
8. `L2 PASS` for the five main-workflow repositories
9. Two actual cross-repository pilots

Current recorded status:

- `backend / web-portal / admin-web / mobile-a / mobile-b`: main workflow `L2 PASS`
- `backend / mobile-a / mobile-b`: `L1 WARN` allowed
- `mobile-c / miniapp`: `missing-contract`
- Completed:
  - `CHG-2026-0002-local-refund-audit-pilot`
  - `CHG-2026-0003-local-company-audit-pilot`
  - `CHG-2026-0004-mobile-login-safearea-nohandcode`, currently the conditional-success example for single-repository no-hand-code execution
- Latest local baseline report:
  - `reports/local-validation/20260402-112417-summary.md`

## 5. Remaining gaps

The current system does not fully match the official model. Most gaps are in execution:

1. Fully automatic startup of repository worker runtimes
2. Automatic worker code changes and result writeback
3. An automatic review loop that returns work to repository workers
4. Persistent threads/sessions
5. Live MCP / observability
6. A default team-wide working method
7. Strict isolation between clean worktrees and the main repository's dirty working tree
8. Reliable separation of environment-caused false failures from actual business regressions
9. Stable external runtime resources when starting repository workers automatically

The current assessment is:

- The control plane is approaching maturity.
- The execution runtime is still evolving through V1.

## 6. The V1 definition of no-hand-code development

At this stage:

- Workers write business code, tests, and routine fixes by default.
- People handle:
  - Selecting requests
  - Approving change records
  - Approving worker results
  - High-risk tradeoffs
  - Fixing the harness itself

Direct human intervention in business code is allowed only when:

1. The harness itself has a bug.
2. The worker fails repeatedly.
3. Rule conflicts cannot be resolved automatically.

## 7. Recommended implementation direction

### Stage A: single-repository no-hand-code execution first

Start with `mobile-a` because:

- Its command workflow is mature.
- Both pilots already used it as the primary changed repository.
- It is the best place to stabilize actual repository-worker execution.
- The next task must be small: **one repository, one file, and no external environment dependencies**, executed in an isolated, clean worktree.

Goals:

- `dispatch-change -> run-role -Execute -> worker result -> review worker -> consolidated verification`
- People do not write business code manually.
- `CHG-2026-0004-mobile-login-safearea-nohandcode` has demonstrated that:
  - A repository worker can make actual changes to `ExampleScreen.tsx` in a clean worktree.
  - V1 now has two essential runtime behaviors:
    - It assesses **success within the write scope** separately from **pre-existing repository-level blockers**.
    - The dispatcher uses `snapshot_policy: source_dirty_tracked` to synchronize the main repository's tracked dirty snapshot into an isolated worktree.
  - The remaining primary blocker has shifted from outdated worktree baselines to external usage limits / runtime resources during actual worker execution.

Follow this fixed order:

1. Retain `CHG-2026-0004-mobile-login-safearea-nohandcode` as the first conditional-pass example.
2. When the external runtime recovers, rerun its existing workflow first:
   - `dispatch-change.ps1`
   - `run-role.ps1 -Execute`
   - `review-worker-output.ps1 -Execute`
   - `verification-agent` updates `verification/result.md`
3. Start a second `mobile-a` single-repository no-hand-code task only after this workflow passes unconditionally.
4. Expand to `backend + admin-web/web-portal + mobile-a` only after both `mobile-a` tasks succeed reliably.

Until then, exclude:

- Parallel execution across repositories
- Live MCP
- Persistent App Server / thread manager
- `mobile-c / miniapp` in the main no-hand-code workflow
- Remote commits / deployment preparation

### Stage B: expand to three repositories in parallel

Expand to:

- `backend`
- `admin-web/web-portal`
- `mobile-a`

Goals:

- Actual workers independently handle all three repositories.
- The main workflow maintains `L2 PASS`.

### Stage C: move to the V2 runtime

Only after the first two stages are stable, consider:

- Thread persistence
- Automated lock services
- Live MCP
- Observability workers
- A design closer to the official App Server model

## 8. Current development framework

Use this execution framework:

1. Run outer control-repository gates: `validate-repos -> verify-workspace -> discover-contracts -> run-local-baseline`.
2. Create and complete the change record: `brief -> impact -> execution -> design -> tasks`.
3. The dispatcher reads `execution.yaml` and assigns a worker to each affected repository.
4. Each repository worker edits code and runs verification in an isolated worktree, then records `verification/workers/*.md`.
5. The review worker / verification-agent reads diffs, command output, and worker results to decide whether work must return to the repository worker.
6. After passing, complete `acceptance.md`, `verification/result.md`, and `postmortem.md`.
7. Stop there at this stage; do not proceed to commit, push, or deployment.

## 8.1 Latest progress

Additional capabilities now implemented:

- `execution.yaml` supports `snapshot_policy`.
- The dispatcher synchronizes source-repository tracked dirty snapshots into isolated worktrees.
- `dispatch-state.json` records:
  - `snapshot_policy`
  - `snapshot_source`
  - `snapshot_tracked_files`
  - `snapshot_actions`

The largest runtime uncertainty has shifted from workers using an outdated `HEAD` baseline to whether repository workers can reliably obtain external runtime resources and complete a full execution cycle.

The practical next steps are:

- Preserve the current `CHG-2026-0004` example.
- Rerun its workflow when the external runtime recovers.
- Do not declare no-hand-code V1 successful or start another conceptual pilot until one unblocked `repo worker -> review worker -> verification-agent` cycle completes.

## 9. Summary

The example product has established the control-plane foundation described in official harness engineering guidance. The next priority is reliable execution of **dispatcher -> actual worker -> review worker -> consolidated verification**, making no-hand-code business development dependable in the local main workflow.
