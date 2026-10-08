# AI Collaboration Guide for the Example Product Harness Repository

This repository is the control center for development across the example product's repositories. Every AI assistant working here must follow these rules.

## 1. What to read first

Read context in this order when starting a task:

1. [repos/repos.yaml](repos/repos.yaml)
2. [docs/harness-engineering.md](docs/harness-engineering.md)
3. [docs/workflow.md](docs/workflow.md)
4. [docs/agent-workflow-skill-mcp.md](docs/agent-workflow-skill-mcp.md)
5. [docs/memory-governance.md](docs/memory-governance.md)
6. [docs/rule-precedence.md](docs/rule-precedence.md)
7. Files under the relevant `changes/<change-id>/`, especially `execution.yaml`
8. [docs/cross-repo/README.md](docs/cross-repo/README.md) and related indexes
9. Rules for affected repositories
10. The latest `reports/local-validation/` report, if the task involves local verification

## 2. Prohibited actions

- Do not begin work in a business repository without a `change-id`.
- Do not declare the development phase started without `impact.yaml`.
- Do not dispatch concurrent execution agents without `execution.yaml`.
- Do not declare a cross-platform request complete based only on one repository's tests.
- Do not issue a release conclusion without rollback instructions.
- Do not commit the seven business repositories' application code into this repository.
- Do not use production databases, Redis, RabbitMQ, Nacos, or MinIO as default verification environments.
- Do not let two agents write the same primary control-repository artifact at the same time.
- Do not let multiple agents share a writable worktree.

## 3. Required minimum artifacts

Each change must include at least:

- `brief.md`
- `impact.yaml`
- `execution.yaml`
- `acceptance.md`
- One task card
- `verification/result.md`

## 4. Task breakdown rules

- Break each cross-repository request into repository-level task cards.
- Each task card describes one repository's inputs, outputs, boundaries, and verification commands.
- Record cross-repository ordering dependencies in `impact.yaml`.
- For concurrent execution, explicitly record the owner, write_scope, branch, worktree, and lock_state in `execution.yaml`.

## 5. Responsibility boundaries

This repository is responsible for:

- Request management
- Agent / Workflow / Skill / MCP control-plane design
- Archiving design decisions
- Task orchestration
- Regression cases
- Release gates
- AI rules
- Local workspace synchronization and safety baseline verification

This repository is not responsible for:

- Storing business application code
- Replacing business-repository READMEs or rules
- Replacing business-repository CI
- Connecting to production environments or production MCP by default

## 6. Control-repository skills and blueprints

- Keep workflow skills in `.agent/skills/`.
- Governance skills also include memory routing, rule resolution, and converting postmortems into regression coverage.
- Keep MCP blueprints and integration policies in `mcp/`.
- At this stage, design and integrate only **read-only, nonproduction** MCP services.
- Prioritize workflow skills at this stage; do not continue expanding page-generation skills.

## 7. Default language and output style

- Use American English by default.
- Write requirements, documentation, comments, and verification results in American English.
- Preserve commands, paths, and interface names as needed.

## 8. Recommended execution order

1. Run `validate-repos.ps1`.
2. When local workspace setup is required, first run `clone-repos.ps1 -DryRun`.
3. Run `discover-contracts.ps1` and `run-local-baseline.ps1`.
4. Create or inspect the change record and complete `execution.yaml`.
5. Use control-repository skills to prepare the `brief`, `impact`, `task`, `release`, and `postmortem` documents.
6. Run `dispatch-change.ps1` before entering the no-hand-code worker workflow.
7. Work in each business repository according to its task card, worker packet, and `execution.yaml`.
8. Return to the control repository to complete acceptance, release, and postmortem records.
