# MOB-001 Enterprise to-do items are visible in the app

## Type

- Documented regression case
- Planned automation: Maestro

## Goals

Verify that to-do items created by the platform or enterprise administration portal appear correctly in `mobile-a`.

## Inputs

- The enterprise administration portal or platform has created a to-do item for enterprise staff

## Steps

1. Trigger creation of a to-do item in the administration portal
2. Sign in to `mobile-a`
3. Open the to-do list
4. View the to-do item details

## Expected results

- The to-do item is visible
- The title, status, time, and source are correct
- Selecting the item opens the correct details or processing page
