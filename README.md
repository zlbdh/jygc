# Agent Harness Control Repository — Sanitized Public Edition

This sanitized public edition is based on a real local control repository for collaboration across multiple repositories. It demonstrates how agents, workflows, skills, and MCP support engineering collaboration, task dispatch, verification, and evidence collection. Project names, organization names, remote URLs, repository roles, and paths have been generalized into examples. Actual business code, runtime snapshots, screenshots, logs, reports, and identifiable business information are excluded.

`example-product-harness` is the development control plane for the example product's seven repositories.
It coordinates **request intake, cross-repository impact analysis, task breakdown, local baselines, cross-repository acceptance, release governance, and knowledge feedback**. Business application code stays in its own repositories.

The control plane currently covers these business repositories:

- `example-product-backend`: Backend microservices
- `example-product-web-portal`: Enterprise desktop web portal
- `example-product-admin-web`: Example product platform administration portal
- `example-product-mobile-a`: Enterprise mobile app
- `example-product-mobile-b`: Merchant app
- `example-product-mobile-c`: Staff app
- `example-product-miniapp`: Consumer miniapp

## Repository purpose

- Manage change IDs for cross-repository requests in one place
- Document the control-plane design for agents, workflows, skills, and MCP
- Provide local synchronization, contract discovery, and a risk matrix for all seven repositories
- Manage task cards, acceptance records, release records, and postmortems centrally
- Make development collaboration structured, auditable, and reproducible

## Current maturity snapshot

- `backend`, `web-portal`, `admin-web`, `mobile-a`, `mobile-b`: The main workflow has reached local baseline status `L2 PASS`
- `backend`, `mobile-a`, `mobile-b`: Local `L1 WARN` is allowed, usually because of uncommitted changes rather than command failures
- `mobile-c`, `miniapp`: Remain prototype repositories with `missing-contract` status and are excluded from the main no-hand-code workflow for now
- Control repository: the knowledge layer, local verification layer, and packet-based worker harness are in place. Live MCP, automated locking, and persistent thread services remain to be added

## Key documents

- [docs/harness-engineering.md](docs/harness-engineering.md): Harness engineering and its specific meaning for the example product
- [docs/workflow.md](docs/workflow.md): The complete development and release workflow
- [docs/agent-workflow-skill-mcp.md](docs/agent-workflow-skill-mcp.md): Current and target inventories of agents, workflows, skills, and MCP
- [docs/worker-harness-v1.md](docs/worker-harness-v1.md): V1 local worker dispatch, packets, and review execution
- [docs/official-harness-mapping.md](docs/official-harness-mapping.md): Mapping official harness engineering guidance to the example product, including gaps and next steps
- [docs/memory-governance.md](docs/memory-governance.md): Memory layers, sources of truth, and writeback rules
- [docs/rule-precedence.md](docs/rule-precedence.md): Rule precedence, conflict resolution, and metadata requirements
- [docs/harness-sop.md](docs/harness-sop.md): Standard harness engineering procedure for the example product
- [docs/module-practical-template.md](docs/module-practical-template.md): A complete practical template for adding a module
- [docs/architecture.md](docs/architecture.md): Architecture of the control plane and seven-repository collaboration
- [docs/command-contract.md](docs/command-contract.md): Minimum command contracts for each repository
- [docs/cross-repo/README.md](docs/cross-repo/README.md): Entry point for cross-repository workflows, dependency maps, and contract indexes

## Directory overview

```text
.
├── AGENTS.md
├── repos/
│   └── repos.yaml
├── docs/
├── standards/
├── templates/
├── changes/
├── evals/
├── reports/
├── release/
├── mcp/
└── scripts/
```

## Memory and rule model

The control plane uses a defined layered model:

- Repository artifacts provide **long-term memory**
- Threads and conversations provide **short-term memory**
- MCP provides **external, read-only context**
- Skills provide **reusable execution procedures**
- Workflows define **orchestration order**
- Rules define **boundaries, gates, and conflict resolution**

Maintain facts in the respective sources of truth for the control repository and business repositories. A universal memory database is outside the default design.

## Quick start

1. Validate the control-repository structure and business-repository inventory:

```powershell
.\scripts\checks\validate-repos.ps1
.\scripts\bootstrap\verify-workspace.ps1
```

2. Preview or execute synchronization of the seven repositories:

```powershell
.\scripts\bootstrap\clone-repos.ps1 -DryRun
.\scripts\bootstrap\sync-repos.ps1 -DryRun
```

3. Discover repository contracts and generate baseline reports:

```powershell
.\scripts\checks\discover-contracts.ps1
.\scripts\checks\run-local-baseline.ps1
```

4. Create and validate a new change record:

```powershell
.\scripts\bootstrap\init-change.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -Title "Initialize the development control repository"
.\scripts\checks\validate-change.ps1 -ChangeId CHG-2026-0001-bootstrap-harness
```

5. Generate a local worker dispatch packet for a change, with optional no-hand-code smoke testing:

```powershell
.\scripts\orchestrator\dispatch-change.ps1 -ChangeId CHG-2026-0001-bootstrap-harness
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -RepoId backend -PrintPacket
.\scripts\orchestrator\run-role.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -RepoId backend -Execute -NoCodeChanges -Ephemeral
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-2026-0001-bootstrap-harness
.\scripts\orchestrator\review-worker-output.ps1 -ChangeId CHG-2026-0001-bootstrap-harness -RepoIds backend -Execute -Ephemeral
```

## Control-plane components

- `repos/repos.yaml`: Single source of truth for the seven repository roles and command discovery
- `docs/`: Global concepts, architecture, workflows, and inventories
- `standards/`: Global gates and platform-specific rules
- `templates/`: Templates for changes, designs, execution status, acceptance, verification, releases, and postmortems
- `.agent/skills/`: Workflow skills for the control repository
- `mcp/`: Read-only, nonproduction MCP blueprints and integration policies
- `reports/`: Local verification and diagnostic output

## Local code layout convention

Local working copies of business repositories belong under `D:\workspace\agent-harness\repos\` and are excluded from control-repository version control by default.
[repos/repos.yaml](repos/repos.yaml) is the authoritative source for business-repository metadata.

Each change also creates an instance of [execution.yaml](templates/execution.yaml) to record:

- Current stage
- Current stage owner
- repo owner
- Write boundaries
- worktree / branch
- Lock state
- Snapshot time

## Local verification reports

Local synchronization, self-check, and baseline verification results are written to:

- [reports/README.md](reports/README.md)
- `D:\workspace\agent-harness\reports\local-validation\`

These reports are required minimum gates for local verification before any production work.
