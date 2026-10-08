# api-contract-readonly

## Goals

Provide a shared view of API contracts, field descriptions, and examples needed for collaboration between `backend` and other platforms.

## Allowed capabilities

- Read OpenAPI / Postman / JSON Schema
- Inspect request parameters, response fields, and error codes
- View API examples

## Prohibited capabilities

- Calling APIs that perform writes
- Modifying API definitions
- Connecting to production gateways

## Use cases

- Creating `brief.md` and `impact.yaml`
- Preparing task cards for `web-portal / admin-web / mobile-a / mobile-b`
- Checking cross-repository acceptance against API contracts
