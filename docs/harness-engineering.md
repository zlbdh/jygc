# Harness Engineering in the Example Product

## 1. What harness engineering means

For the example product, harness engineering establishes a unified **control plane** for seven business repositories. Requirements, development, verification, releases, and postmortems operate under shared rules.

Its four core goals are:

- Control: know where requests enter, who receives each task, and where code changes happen.
- Verification: know which checks ran, which workflows were verified, and which risks remain open.
- Auditability: know who changed what, why a release is allowed, and how to reconstruct a failure.
- Feedback: turn problems into improvements to templates, rules, skills, and regression coverage.

## 2. What it covers in the example product

The control plane covers the following layers.

### 2.1 Knowledge layer

- `docs/`
- `standards/`
- `templates/`
- `changes/`

Responsibility: turn requirement context, workflow rules, acceptance criteria, and past experience into repository sources of truth.

### 2.2 Execution layer

- `repos/repos.yaml`
- `execution.yaml`
- Task cards
- Division of work across business repositories
- Control-repository skills

Responsibility: have people and agents execute from the same structured inputs.

### 2.3 Verification layer

- Local baselines
- Contract discovery
- Minimum command contracts within repositories
- Cross-repository acceptance

Responsibility: provide inspectable evidence for correctness.

### 2.4 Release governance layer

- Release records
- Rollback instructions
- Post-release monitoring points
- Postmortem records

Responsibility: make deployment a controlled delivery process beyond merely merging code.

### 2.5 Memory and rule layer

- `docs/memory-governance.md`
- `docs/rule-precedence.md`
- `docs/cross-repo/`

Responsibility: define long-term memory, sources of truth, rule precedence, and where long-term cross-repository knowledge belongs.

## 3. Current project status

### 3.1 Existing capabilities

- The control repository is established as the unified workspace entry point for all seven repositories.
- Local copies of all seven repositories are under `D:\workspace\agent-harness\repos\`.
- The `clone / sync / discover / baseline` workflow has run successfully.
- Change records, task cards, acceptance records, and release records have templates and script entry points.

### 3.2 Current maturity assessment

- `web-portal`, `admin-web`: local baselines pass.
- `backend`, `mobile-a`, `mobile-b`: executable, with real quality issues still to address.
- `mobile-c`, `miniapp`: not yet standard executable projects.
- Control repository: knowledge and local verification layers are established; cross-repository acceptance and release governance are not yet complete.

### 3.3 Latest stage assessment

- Local harness engineering has been verified successfully.
- The control plane is mature: the control repository, change records, baseline workflow, role registry, dispatcher, and worker/review packets are implemented.
- Single-repository no-hand-code execution has achieved conditional success, but not unconditional success with a purely no-hand-code process.
- `CHG-2026-0004-mobile-login-safearea-nohandcode` demonstrated that:
  - A repository worker can make actual code changes in an isolated worktree.
  - `source_dirty_tracked` resolves worktree baselines lagging behind the main repository's local baseline.
  - The primary blocker is now external `codex exec` usage limits / runtime resources, rather than snapshot design.
- The current assessment is therefore:
  - The control plane works.
  - The execution runtime is connected.
  - The system is still evolving through local V1.

## 4. Goals at this stage

The immediate goal is a system for:

- Controlled development
- Repeatable verification
- Auditable releases

Fully automated AI development in a single step is outside the current target. Success is measured by whether:

- New requests enter through the control repository.
- Business repositories execute from task cards.
- Local baselines and cross-repository acceptance block obvious risks.
- Structured evidence exists before release.

The more specific current goals are:

- First complete the initial single-repository no-hand-code example for `mobile-a`.
- Do not start with parallel execution across repositories.
- Do not integrate live MCP first.
- Do not start with remote commits or deployment preparation.
- Only after `CHG-2026-0004` passes without blockers on its `source_dirty_tracked` worktree should work proceed to a second `mobile-a` task, then expand to multiple repositories.

## 5. Why this is needed now

- The project now requires coordination across repositories, beyond verbal synchronization.
- Existing quality issues require shared gates to distinguish old problems from new ones.
- Business-repository rules and skills exist but remain scattered rather than organized into control-plane capabilities.
- No MCP resources are currently available, so context still depends on local files and terminal output; organizing facts in the control repository is particularly important.
- `execution.yaml` addresses concurrent execution questions: who is writing, where they are writing, and which snapshot they are using.
