# Example Product Worker Harness V1

## 1. Purpose

Worker Harness V1 adds a runtime layer to the control repository during the local-verification-first stage. Before implementing OpenAI App Server / JSON-RPC directly, it combines the existing:

- `execution.yaml`
- Change record structure
- Local baseline workflow
- Control-repository skills

into an executable protocol with a **local dispatcher, repository workers, review workers, and packet/evidence storage**.

## 2. Problems it addresses

`backend-exec-agent / admin-web-exec-agent / mobile-a-exec-agent` already exist as project role names, but previously served only as owner labels in documentation. V1 adds:

- `config/agent-registry.yaml`: machine-readable role definitions
- `scripts/orchestrator/dispatch-change.ps1`: dispatches change records into repository worker packets and can optionally start workers
- `scripts/orchestrator/run-role.ps1`: the single-repository worker entry point, with actual execution through `codex exec`
- `scripts/orchestrator/review-worker-output.ps1`: generates review packets and can optionally start read-only review workers
- `verification/workers/*.md`: recorded results for each repository worker
- `runtime/worker-responses/*.json`: structured, machine-readable repository worker results
- `runtime/review-results/*.json`: structured, machine-readable review worker results

## 3. Usage sequence

### 3.1 Complete outer control-repository gates

```powershell
.\scripts\checks\validate-repos.ps1
.\scripts\bootstrap\verify-workspace.ps1
.\scripts\checks\discover-contracts.ps1
.\scripts\checks\run-local-baseline.ps1
```

### 3.2 Create and complete a change record

```powershell
.\scripts\bootstrap\init-change.ps1 -ChangeId CHG-YYYY-NNNN-slug -Title "Request title"
.\scripts\checks\validate-change.ps1 -ChangeId CHG-YYYY-NNNN-slug
```

### 3.3 Generate a worker dispatch packet

```powershell
.\scripts\orchestrator\dispatch-change.ps1 -ChangeId CHG-YYYY-NNNN-slug
```

Outputs:

- `changes/<change-id>/runtime/dispatch-state.json`
- `changes/<change-id>/runtime/packets/<repo>-worker.md`
- `changes/<change-id>/verification/workers/<repo>.md`

### 3.4 Inspect one repository worker packet

```powershell
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -PrintPacket
```

### 3.5 Execute one repository worker

```powershell
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -Execute -Ephemeral
```

Outputs:

- `changes/<change-id>/verification/workers/<repo>.md`
- `changes/<change-id>/runtime/worker-responses/<repo>.json`

Options:

- `-Execute`: actually starts the local repository worker
- `-Ephemeral`: uses a short-lived session
- `-NoCodeChanges`: runs only a no-hand-code smoke test without editing code

If `dispatch-change.ps1` has already synchronized a `source_dirty_tracked` snapshot into the repository's worktree, use this for subsequent execution:

```powershell
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-YYYY-NNNN-slug -RepoId backend -Execute -SkipDispatch
```

Reasons:

- A worktree containing a synchronized snapshot is no longer a clean `HEAD`.
- Reusing an entry point that triggers dispatch, such as `-EnsureWorktrees`, makes the dispatcher mark the run `blocked` because the target worktree is dirty.
- The correct V1 sequence is therefore:
  1. `dispatch-change.ps1`
  2. `run-role.ps1 -Execute -SkipDispatch`
  3. `review-worker-output.ps1 -Execute`

### 3.6 Generate or execute a review worker

```powershell
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-YYYY-NNNN-slug
```

To execute a read-only review worker:

```powershell
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-YYYY-NNNN-slug -Execute -Ephemeral
```

Outputs:

- `changes/<change-id>/runtime/reviews/<repo>-review.md`
- `changes/<change-id>/runtime/review-state.json`
- `changes/<change-id>/runtime/review-results/<repo>.json`

## 4. Worker execution protocol

### 4.1 Fixed repository-worker inputs

- `brief.md`
- `impact.yaml`
- `execution.yaml`
- `tasks/<repo>.md`
- Repository rules
- Latest local baseline summary

### 4.2 Fixed repository-worker actions

1. Read the task card and write scope.
2. Operate only within `allowed_paths` and the worktree.
3. Modify code, tests, or contract calls.
4. Run the minimum repository verification commands defined in the registry.
5. Return JSON matching the schema.
6. The wrapper saves it to:
   - `verification/workers/<repo>.md`
   - `runtime/worker-responses/<repo>.json`

### 4.3 Fixed review-worker actions

1. Read the worker result, diff, Git status, and task card.
2. Check for out-of-scope changes.
3. Check whether repository verification ran.
4. Check consistency with `impact/design/tasks`.
5. Return JSON matching the schema.
6. The wrapper saves it to:
   - `runtime/reviews/<repo>-review.md`
   - `runtime/review-results/<repo>.json`

## 5. Current boundaries

- The runtime is still a **local-first worker harness**.
- Live MCP is not integrated.
- Local repository workers and read-only review workers can now be started.
- There is no persistent thread manager / App Server yet.
- Results are not automatically merged into `verification/result.md`.
- The default remains **AI review followed by human approval**.
- Actual code-editing tasks should use **isolated, clean worktrees**.
- Repository workers cannot yet reliably complete no-hand-code work in the main repository's dirty working tree. That working tree is restricted to read-only inspection and is no longer an actual code-editing entry point.

## 6. Key principles

- Roles are registry entities rather than documentation labels.
- The dispatcher assigns work without deciding business correctness.
- Workers write only permitted paths in their own repositories.
- Actual code-editing tasks run only in the isolated worktree specified by `execution.yaml`.
- Repository workers write back only to `verification/workers/*.md`.
- verification-agent remains responsible for the primary verification conclusion.
- `verification/result.md` contains verification-agent's consolidated conclusion and must not be overwritten by an individual worker.

## 6.1 Scoped verification and pre-existing repository issues

The initial V1 single-repository no-hand-code tasks deliberately use:

- One repository
- One file or a very small write scope
- No external environment dependencies

Their primary goal is to prove that **repository workers can make actual code changes in clean worktrees**. Assess two distinct facts:

1. **Success within the write scope**
   - Did the worker actually change code in permitted paths?
   - Did target-file or scope-level verification pass?
2. **Pre-existing repository-level blockers**
   - Are repository-wide `npm run lint` / build failures caused by existing issues outside the write scope?

Under current V1 rules, if actual changes occurred within the write scope and target-file verification passed, while repository-wide failures are proven to come from pre-existing issues outside the scope, classify the run as:

- Repository worker: `blocked`
- Review worker: `approved`, explicitly labeled a conditional pass
- verification-agent: record **scope passed; pre-existing repository issues block full verification** in `verification/result.md`

Do not classify this as a worker code-implementation failure.

If `source_dirty_tracked` synchronized successfully but an external `runtime / usage limit` blocks actual repository-worker execution, classify it as:

- Repository worker: `blocked`
- Review worker: `blocked`, with `verification_check = blocked_by_runtime`
- verification-agent: record **snapshot synchronization is effective, but external runtime resources block execution; this run cannot be declared passed** in `verification/result.md`

This also must not be mistaken for an implementation failure within the write scope.

V1 now includes an essential runtime policy:

- `snapshot_policy: source_dirty_tracked`

This means:

- Isolated worktrees are no longer based only on Git `HEAD`.
- The dispatcher synchronizes the source repository's current uncommitted snapshot of **tracked files** into the isolated worktree.
- Workers see the actual current local baseline rather than an outdated `HEAD`.

Current implementation boundaries:

1. Synchronize **tracked dirty files** only.
2. Do not synchronize untracked files automatically.
3. If the write scope depends on untracked files, the dispatcher marks it `blocked`.
4. A dirty target worktree or inconsistent branch anchor also produces `blocked`.

Single-repository no-hand-code assessment must distinguish:

1. **Pre-existing issues outside the scope**
2. **Whether source_dirty_tracked synchronized into the worktree**
3. **Whether the repository worker actually changed code on the synchronized baseline**

Do not equate repository-wide gate failures with worker implementation failures without separating these three layers.

## 6.2 The V1 narrow snapshot policy for `source_dirty_tracked`

`source_dirty_tracked` lets workers see the source repository's actual tracked dirty baseline instead of only an outdated `HEAD`.

`CHG-2026-0004 / mobile-a` demonstrated that synchronizing all tracked dirty source files into a worktree conflicts with single-file or very small write-scope tasks.

V1 therefore uses these rules:

1. Keep `snapshot_policy: source_dirty_tracked` as the default.
2. Synchronize only **tracked dirty files within the current write scope**.
3. For tracked dirty files outside the write scope:
   - Record them in `snapshot_actions`.
   - Do not synchronize them into the current worktree.

`dispatch-state.json` must include at least:

- `snapshot_policy`
- `snapshot_source`
- `snapshot_tracked_files`
- `snapshot_actions`

Examples:

- `synced-modified:src/screens/ExampleScreen.tsx`
- `ignored-out-of-scope-tracked:94`
- `captured-source-dirty-tracked`

The narrow snapshot policy aligns four scopes:

1. The worker's actual worktree scope
2. The write scope declared in the task card
3. The Git diff scope seen by the review worker
4. The scope covered by repository verification commands

Do not declare single-repository no-hand-code success before these four scopes align.

## 6.3 Source dependency baseline and worktree dependency availability

The worktree's `node_modules` is not installed independently. When creating or reusing a worktree, the dispatcher prefers reusing the source repository's `node_modules`.

Consequences:

1. If the source repository has no `node_modules`, the worktree does not automatically gain local dependencies.
2. If source `node_modules` exists but local executable entries such as `.bin/eslint` or `.bin/expo` are incomplete, the worktree inherits that incomplete state.
3. Classify these problems as `blocked_by_environment`, rather than business implementation failures.

Minimum practice:

- Before actual worker execution, the source repository should have usable:
  - `node_modules/.bin/eslint`
  - `node_modules/.bin/expo`, if smoke tests still depend on Expo CLI
- If these are missing, restore the source repository's local dependency baseline before rerunning workers and reviews.

`CHG-2026-0004` verified that:

- Missing dependencies should make review conclude `blocked_by_environment`.
- Once dependencies are restored, the primary blocker shifts back to the worker itself or the external runtime.

## 6.4 Collecting external runtime / usage limit evidence

V1 repository workers execute through `codex exec`. When it returns no structured JSON matching the schema, retain the console output as well as inspecting an empty `raw_response`.

Minimum rules:

1. `run-role.ps1` saves `codex exec` console output to `runtime/worker-responses/<repo>-console.log`.
2. If the worker returns no structured JSON, inspect `console.log` before classifying the run as `blocked_by_runtime` or a generic external execution-layer block.
3. If the console contains `You've hit your usage limit`, `try again at`, or equivalent quota/window messages, explicitly record an **external `codex exec` usage limit block**.
4. Do not classify these cases as:
   - Implementation failures within the write scope
   - Review failures
   - Inability to modify business code

## 7. Next steps

The priority is to complete the first actual **single-repository no-hand-code** workflow before expanding the control plane further.

Follow this order:

1. Keep `CHG-2026-0004-mobile-login-safearea-nohandcode` as the first conditional-pass example; do not start another single-repository no-hand-code task yet.
2. Retain the narrow `source_dirty_tracked` snapshot policy rather than reverting to all tracked dirty files.
3. Keep the source repository's local dependencies usable.
4. When the external runtime recovers, rerun `CHG-2026-0004 / mobile-a` on the same worktree baseline.
5. The review worker issues `approved / needs_rework / blocked_by_runtime` based only on the current diff, worker result, and command results.
6. verification-agent consolidates the conclusion in `verification/result.md`.
7. Start a second `mobile-a` task only after `CHG-2026-0004` passes unconditionally.

Already demonstrated:

- `source_dirty_tracked` can synchronize tracked dirty source snapshots into isolated worktrees within the write scope.
- `dispatch-state.json` records `snapshot_policy / snapshot_source / snapshot_actions`.
- Local dependency baselines can be restored in the source/worktree.
- The remaining blockers are no longer mismatched worktree baselines or missing dependencies. They are:
  - External `codex exec` runtime / usage limits
  - The repository worker has not yet returned structured JSON during an unblocked execution cycle

Do not declare no-hand-code V1 successful or start new conceptual pilots until actual worker execution aligns snapshot scope, task boundaries, review scope, and verification scope, and the current run is free of external runtime blocks.
