# Agent / Workflow / Skill / MCP Inventory

## 1. Current capabilities and gaps

### 1.1 Agents

- The platform provides a primary agent and three subagent capabilities: `default / explorer / worker`.
- The control repository defines logical project roles in the machine-readable [agent-registry.yaml](config/agent-registry.yaml).
- There are still **no new custom platform-level agent types**. The registry maps project roles to existing runtimes.
- Roles are now available; the remaining gaps are **persistent thread services and automated locking**.

### 1.2 Workflows

The following workflows are implemented:

- `workspace-baseline-workflow`: `clone -> sync -> discover -> baseline`
- `change-intake-workflow`: `change-id -> brief -> execution`
- `impact-design-workflow`: `brief -> impact -> design -> execution`
- `task-splitting-workflow`: `impact/design -> tasks -> repo owner`
- `repo-execution-workflow`: task card -> repository execution -> repository verification
- `cross-repo-acceptance-workflow`: `acceptance -> verification/result`
- `release-governance-workflow`: `release-note -> rollback -> observe`
- `knowledge-feedback-workflow`: `postmortem -> rules/templates/evals/skills`

### 1.3 Skills

System skills available in the documented session:

- `security-best-practices`
- `imagegen`
- `openai-docs`
- `plugin-creator`
- `skill-creator`
- `skill-installer`

Existing project skills in business repositories:

- `mobile-a`
  - `api-integration-workflow`
  - `business-dictionaries`
  - `ui-ux-pro-max`
  - `yjl-app-generator`
- `mobile-b`
  - `business-dictionaries`
  - `mobile-b-generator`
  - `ui-ux-pro-max`
  - `yjl-app-generator`
- `miniapp`
  - `ui-ux-pro-max`
  - `miniapp-generator`

Business repositories also contain many `.agent/rules` files. `mobile-a` has especially extensive business rules, but these rules remain **distributed across individual repositories**.

### 1.4 MCP

Current status:

- No MCP resources
- No MCP templates

Context therefore still comes primarily from:

- The local filesystem
- Control-repository scripts
- Terminal output

## 2. Agent capabilities to add at this stage

| Agent | Responsibilities | Outside its responsibilities |
|-------|------------------|------------------------------|
| `change-intake-agent` | Turn unclear requests into `brief.md` | Direct business-code changes |
| `impact-design-agent` | Produce `impact.yaml` and lightweight `design.md` | Direct release conclusions |
| `backend-agent` | `backend` only | Web / mobile changes |
| `web-agent` | `web-portal`, `admin-web` only | Backend / mobile changes |
| `mobile-agent` | `mobile-a`, `mobile-b` only | `mobile-c` by default at this stage |
| `verification-agent` | Consolidate repository checks, baselines, and acceptance records | Replacing implementation agents |
| `release-agent` | Produce release records, rollback records, and release order | Deciding business correctness |
| `knowledge-agent` | Feed problems back into rules, templates, regression cases, and skills | Performing releases |

## 3. Workflow capabilities to add at this stage

| Workflow | Main inputs | Main outputs |
|----------|-------------|--------------|
| `workspace-baseline-workflow` | `repos.yaml` | Contract discovery reports, baseline matrix |
| `change-intake-workflow` | Original requests, bugs, incidents | `brief.md`, `impact.yaml` |
| `repo-execution-workflow` | `tasks/*.md` | Code changes, repository verification results |
| `cross-repo-acceptance-workflow` | `acceptance.md` | `verification/result.md` |
| `release-governance-workflow` | Acceptance results, branches, configuration changes | Release records, rollback steps, monitoring points |
| `knowledge-feedback-workflow` | Problems, incidents, rework | `postmortem.md`, new rules, new regression cases |

## 4. Control-repository skills to add at this stage

These skills have scaffolding under `.agent/skills/`. Prioritize **workflow capabilities**:

| Skill | Trigger | Main output |
|-------|---------|-------------|
| `change-intake` | A request enters the control repository | Draft `brief.md` |
| `cross-repo-impact` | Identify affected repositories | Draft `impact.yaml` |
| `task-card-generator` | Break tasks down by repository | `tasks/*.md` |
| `local-baseline-triage` | Interpret baseline reports | Root-cause assessment and next actions |
| `cross-repo-acceptance-recorder` | Complete acceptance records | `acceptance.md` / `verification/result.md` |
| `release-package-generator` | Prepare a release record | `release-note` / rollback checklist |
| `memory-router` | Decide which sources of truth to read first | Memory routing list, source order, gap list |
| `rule-resolver` | Determine applicable rules and precedence | Precedence results, conflicts, confirmation items |
| `postmortem-to-regression` | Turn incidents into improvements | New regressions, rules, templates, or skill candidates |

## 2. Current and target agent architecture

### 2.1 Current inventory

- Platform layer: primary agent + `default / explorer / worker`
- Control-repository layer: role definitions, [agent-registry.yaml](config/agent-registry.yaml), and local `dispatch-change / run-role / review-worker-output`
- Still absent: persistent thread services, automated locking, and an App Server runtime

### 2.2 V1 agents at this stage

Governance:

- `change-intake-agent`
- `impact-design-agent`
- `verification-agent`
- `release-agent`
- `knowledge-agent`

Execution:

- `backend-exec-agent`
- `web-exec-agent`
- `admin-web-exec-agent`
- `mobile-a-exec-agent`
- `mobile-b-exec-agent`

Prototypes:

- `mobile-c-planning-agent`
- `miniapp-planning-agent`

### 2.3 Long-term V2 agents

- Scheduling agents driven by persistent threads
- Lock and worktree services
- Compatibility matrices and capability registries
- Agents that automate actual cross-repository acceptance

## 3. Memory and invocation model

### 3.1 Memory layers

- Repository artifacts: long-term memory
- Thread conversations: short-term memory
- `reports/`: verification evidence
- `postmortem.md`: failure memory
- MCP: external, read-only context
- Skills: procedural memory / execution procedures

### 3.2 Invocation flow

`User/product -> control-repository workflow -> governance agent -> repository task card -> execution agent -> verification agent -> release agent -> knowledge feedback`

### 3.3 Concurrency principles

- Shared reads: multiple agents may read the same skill, rule document, or read-only MCP service.
- Exclusive writes: only one agent may write a primary control-repository artifact or business repository at a time.
- Shared facts require snapshots: reports, commits, branches, environments, and timestamps.

### 3.4 Current conflict risks

- Multiple agents writing `impact.yaml`
- Multiple agents writing `verification/result.md`
- Multiple agents sharing a writable worktree
- Skill instructions overriding repository rules
- Unsourced MCP results being treated as release evidence

## 4. MCP capabilities to add at this stage

Design and integrate only **read-only, nonproduction** MCP services:

| MCP | Purpose | Current status |
|-----|---------|----------------|
| `db-schema-readonly` | Inspect tables, fields, and indexes | Blueprint planned; not integrated |
| `api-contract-readonly` | Provide shared API contracts and examples | Blueprint planned; not integrated |
| `config-readonly` | Read development/test configuration mappings | Blueprint planned; not integrated |
| `observability-readonly` | Read development/test logs and traces | Blueprint planned; not integrated |

Do not integrate:

- Production database MCP
- Production configuration-center MCP
- Production Redis / MQ MCP
- Any MCP service with default write access

Record MCP integrations in:

- [mcp/catalog.yaml](mcp/catalog.yaml)
- [standards/global/mcp-safety.md](standards/global/mcp-safety.md)

## 5. Priorities at this stage

Prioritize these practical capabilities before defining more agents:

- Clear agent boundaries
- Workflow entry points
- Explicit skill triggers
- Read-only, nonproduction MCP integration policies

All of them support the same controlled development workflow.
