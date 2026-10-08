---
scope: control-plane
owner: harness-core
applies_to:
  - backend
  - web-portal
  - admin-web
  - mobile-a
  - mobile-b
  - mobile-c
  - miniapp
precedence: 3
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# Agent governance rules

## 1. Role boundaries

- `change-intake-agent` handles only request intake and `brief.md`
- `impact-design-agent` handles only impact analysis, design notes, dependency order, and stage-level `execution.yaml`
- `backend-exec-agent` handles only `backend`
- `web-exec-agent` handles only `web-portal`
- `admin-web-exec-agent` handles only `admin-web`
- `mobile-a-exec-agent` handles only `mobile-a`
- `mobile-b-exec-agent` handles only `mobile-b`
- `mobile-c-planning-agent` handles only `mobile-c` planning and analysis before project scaffolding is complete
- `miniapp-planning-agent` handles only `miniapp` planning and analysis before project scaffolding is complete
- `verification-agent` handles only verification, reports, and acceptance records
- `release-agent` handles only release records, rollback records, and monitoring points
- `knowledge-agent` handles only postmortems and knowledge feedback

## 2. Write permissions and locks

- `change-intake-agent` owns primary write access to `brief.md` by default
- `impact-design-agent` owns primary write access to `impact.yaml`, `design.md`, and stage-level `execution.yaml` by default
- `task-card-generator` or the corresponding repository owner owns primary write access to `tasks/<repo>.md` by default
- `verification-agent` owns primary write access to `verification/result.md` by default
- `release-agent` owns primary write access to release records by default
- Only one agent may write a primary control-repository artifact at a time
- Only one agent may write a business repository at a time
- Each execution agent must use an isolated branch / worktree

## 3. Prohibited actions

- Do not begin work without a `change-id`
- Do not begin cross-repository development without `impact.yaml`
- Do not dispatch concurrent execution agents without `execution.yaml`
- Do not let one agent make arbitrary changes across multiple execution boundaries
- Do not let multiple agents share a writable worktree
- Do not base a release conclusion on a single repository's self-tests
- Do not access production environments by default

## 4. Collaboration principles

- Split tasks by repository boundaries before assigning agents
- Write agent output back to structured files in the control repository
- Attach snapshot sources to all conclusions: reports, branches, commits, environments, or timestamps
- Human review focuses on correctness, risks, and release conditions
- Agents do not make business decisions on behalf of accountable owners

## 5. Conflict resolution

- Multiple agents may read the same skill, rule, or read-only MCP concurrently
- If two agents need to write the same artifact, the second may only read or append review comments; it must not write the primary file concurrently
- Do not guess when same-level rules conflict. Record the conflict under `Needs confirmation` in `impact.yaml` or `design.md`
- Prototype repositories `mobile-c` and `miniapp` are currently excluded from the regular execution-agent pool

## 6. Default mode at this stage

- AI performs the primary execution
- Human review before merging
- The control repository is the single entry point
