# API-002 Duplicate submission / idempotency workflow

## Type

- Documented regression case
- Planned automation: API smoke tests

## Goals

Verify idempotency protection for critical creation, approval, message-consumption, and state-change scenarios.

## Inputs

- An API or message consumer that writes critical business state

## Steps

1. Send the same request twice in succession or deliver the same message twice
2. Inspect the database results
3. Inspect business logs and returned results

## Expected results

- No duplicate business data is created
- Returned results are explainable
- Redis keys, uniqueness checks, or locking logic work correctly
