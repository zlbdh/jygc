# db-schema-readonly

## Goals

Provide read-only queries of table structures, fields, indexes, and relationships for `backend` requests.

## Allowed capabilities

- Inspect databases, tables, and fields
- Inspect indexes and constraints
- View table creation statements
- View table and field comments

## Prohibited capabilities

- Executing DDL
- Executing DML
- Executing migration scripts
- Connecting to production databases

## Use cases

- Creating `impact.yaml`
- Checking whether interface changes affect table structures
- Analyzing the impact of export, idempotency, and billing requests
