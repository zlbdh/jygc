---
scope: control-plane
owner: harness-core
applies_to:
  - all-mcp-blueprints
precedence: 1
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# MCP safety rules

## 1. General principles at this stage

- Design and integrate read-only MCP services only
- Use development or test environments only
- Do not connect to production by default
- Do not enable write access by default

## 2. MCP types allowed for planning

- `db-schema-readonly`
- `api-contract-readonly`
- `config-readonly`
- `observability-readonly`

## 3. Prohibited integration types

- Production databases
- Production configuration services
- Production Redis
- Production message queues
- File or operations MCP services with default write access

## 4. Pre-integration checks

- Is the environment explicitly development or test?
- Are capabilities explicitly read-only?
- Is a least-privilege account available?
- Are sensitive keys protected from exposure?
- Is the logging and audit scope defined?
- Can results include a source and timestamp?
- Can live reads be distinguished from snapshot reads?

## 5. Usage rules at this stage

- MCP output alone cannot establish release conclusions by default
- Record the source, environment, and read time for every MCP fact
- MCP provides context without replacing long-term memory in the repository
- Treat MCP results without a source as invalid leads
