# Cross-Repository Contract Index

## 1. Contract types

The control plane primarily covers these cross-repository contracts:

- Code and command contracts: `repos/repos.yaml`, `docs/command-contract.md`
- Change contracts: `brief.md`, `impact.yaml`, `execution.yaml`, `design.md`, `tasks/*.md`
- Acceptance contracts: `acceptance.md`, `verification/result.md`
- Release contracts: release records, rollback instructions, and monitoring points
- External-context contracts: MCP catalog and blueprints

## 2. Available contract entry points

| Type | Entry point | Current status |
|------|-------------|----------------|
| Repository roles | `repos/repos.yaml` | Implemented |
| Command contracts | `docs/command-contract.md` | Implemented |
| Local baseline | `reports/local-validation/` | Implemented |
| Change structure | `templates/` and `changes/` | Implemented |
| Read-only MCP catalog | `mcp/catalog.yaml` | Added in this iteration |
| Local business-repository rules | Each repository's `.agent/rules` and README | Available without a unified index |

## 3. Current gaps

- `backend` API contracts lack a unified export index.
- Page and route contracts for `web-portal / admin-web` remain mainly in code and page implementations.
- Mobile page, navigation, and API contracts for `mobile-a / mobile-b` lack a control-repository index.
- `mobile-c / miniapp` still lack standard project contracts.
