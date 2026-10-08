# API-001 Routing platform orders to enterprises

## Type

- Documented regression case
- Planned automation: API smoke tests

## Goals

Verify that orders originating on the platform route correctly to the target enterprise and subsequent processing workflow.

## Inputs

- The platform can create an order belonging to an enterprise

## Steps

1. Create an order on the platform
2. Inspect order ownership, the enterprise identifier, and state transitions in `backend`
3. Check whether the order is visible in the enterprise portal

## Expected results

- Routing rules work correctly
- The enterprise can see and continue processing the order
- State flow and ownership information are consistent
