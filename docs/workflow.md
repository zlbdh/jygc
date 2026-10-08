# Standard Development Workflow

This repository uses AI for primary execution and human review before merging. Organize every cross-repository request, release preparation, and postmortem around these eight workflows.

## Workflow overview

1. `workspace-baseline-workflow`
2. `change-intake-workflow`
3. `impact-design-workflow`
4. `task-splitting-workflow`
5. `repo-execution-workflow`
6. `cross-repo-acceptance-workflow`
7. `release-governance-workflow`
8. `knowledge-feedback-workflow`

## 0. `workspace-baseline-workflow`

Purpose: synchronize business repositories, discover command contracts, and generate local baseline reports.

Execution order:

1. `scripts\bootstrap\clone-repos.ps1`
2. `scripts\bootstrap\sync-repos.ps1`
3. `scripts\checks\discover-contracts.ps1`
4. `scripts\checks\run-local-baseline.ps1`

Outputs:

- Repository status
- Contract discovery reports
- Baseline matrix

Requirements:

- Operate only under `D:\workspace\agent-harness\repos\` by default.
- Do not connect to production by default.
- Write local reports under `reports/local-validation/`.

A repository without a completed local baseline should not directly support pre-release decisions.

## 1. `change-intake-workflow`

Purpose: turn unclear requests into structured change records.

Execution order:

1. Create a change directory under `changes/<change-id>/`.
2. Complete `brief.md`.
3. Initialize `execution.yaml`.

Core files: `brief.md`, `execution.yaml`.

Gates:

- Do not begin business-repository development without a `change-id`.
- Do not begin impact analysis without `brief.md`.

## 2. `impact-design-workflow`

Purpose: turn business intent into structured impact analysis, lightweight design, and execution status.

Execution order:

1. Complete `impact.yaml`.
2. Complete `design.md`.
3. Update the stage, owner, dependency order, and locks in `execution.yaml`.

Core files: `impact.yaml`, `design.md`, `execution.yaml`.

Gates:

- Do not begin task breakdown or implementation without `impact.yaml`.
- Record same-level rule conflicts as `Needs confirmation`; do not guess.

## 3. `task-splitting-workflow`

Purpose: break cross-repository requests into executable repository task cards and bind execution boundaries.

Execution order:

1. Generate `tasks/*.md`.
2. Assign a `repo_owner` to every affected repository.
3. Record `write_scopes`, `branch`, and `worktree` in `execution.yaml`.

Each task card must specify:

- Inputs
- Outputs
- Change boundaries
- Prohibited changes
- Repository verification commands
- Required pre-release evidence

## 4. `repo-execution-workflow`

Purpose: implement changes and run self-tests within repository boundaries.

Execution order:

1. Read repository rules, command contracts, and `execution.yaml`.
2. Lock the target repository's write boundaries.
3. Modify code according to the task card.
4. Run the repository's minimum command contract first.
5. Record repository verification results and the snapshot used.

Requirements:

- `backend-exec-agent` handles only `backend`.
- `web-exec-agent` handles only `web-portal`.
- `admin-web-exec-agent` handles only `admin-web`.
- `mobile-a-exec-agent` handles only `mobile-a`.
- `mobile-b-exec-agent` handles only `mobile-b`.
- Do not assume `mobile-c` and `miniapp` are release-ready at this stage.
- Only one agent may write a business repository at a time.
- Multiple agents must not share a writable worktree.

## 5. `cross-repo-acceptance-workflow`

Purpose: verify complete user business workflows across repositories, beyond individual repository checks.

Execution order:

1. Use `acceptance.md` as the sole acceptance script.
2. Record actions, expected results, and actual results step by step.
3. Record the supporting reports, branches, commits, and environment snapshots.
4. Record anomalies, gaps, and risks in `verification/result.md`.

Requirements:

- Do not declare a cross-platform request complete based only on repository self-tests.
- The unit of acceptance is a business workflow, not a repository.
- Only `verification-agent` may be the primary writer of `verification/result.md`.

## 6. `release-governance-workflow`

Purpose: establish deployment, rollback, and monitoring readiness.

Execution order:

1. Generate a release record.
2. Summarize repositories, branches, configuration, and data changes.
3. Specify release order.
4. Specify rollback steps.
5. Specify post-release monitoring points.

Requirements:

- Do not issue a release conclusion without rollback instructions.
- Do not begin deployment preparation without acceptance records.
- Include sources and timestamps for all external facts.
- Unsourced MCP conclusions cannot support release decisions.

## 7. `knowledge-feedback-workflow`

Purpose: turn incidents, rework, and missed tests into control-plane improvements.

Execution order:

1. Record problems and root causes in `postmortem.md`.
2. Feed improvements back into rules, templates, regression suites, and skills.
3. Add at least one new rule, template, regression case, or skill.
4. Update control-repository documentation and gates.

Requirements:

- Postmortems are required.
- Problems must not remain only in conversation history.

## 7. Human review and merging

Human review focuses on:

- Whether the request is correctly implemented
- Whether risks are explicitly recorded
- Whether acceptance and release conditions are met

Human review does not replace structured documentation, and verbal claims that testing was completed are insufficient.
