# MCP blueprints

The control repository **does not yet integrate any live MCP services**.
This directory stores only read-only, nonproduction MCP blueprints permitted for planning and integration at the current stage.

This directory has two types of sources of truth:

- Blueprint documentation: `blueprints/`
- Machine-readable catalog: [catalog.yaml](mcp/catalog.yaml)

## MCP services permitted for planning at this stage

- `db-schema-readonly`
- `api-contract-readonly`
- `config-readonly`
- `observability-readonly`

## MCP services prohibited at this stage

- Production databases
- Production configuration services
- Production Redis / MQ
- Operations MCP services with default write access

## Recommended integration order

1. `api-contract-readonly`
2. `db-schema-readonly`
3. `config-readonly`
4. `observability-readonly`

## Usage principles

- Create blueprints before integrating services
- Start with development/test environments before considering higher-tier environments
- Start with read-only access before considering broader capabilities
- All MCP output must include its source and timestamp
