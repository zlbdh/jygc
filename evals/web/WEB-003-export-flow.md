# WEB-003 Export workflow

## Type

- Documented regression case
- Planned automation: Playwright with API integration

## Goals

Verify that enterprise and platform export workflows follow the direct-link export standard.

## Inputs

- At least one list page that supports export

## Steps

1. Open the target list page
2. Select Export
3. Inspect the request path and response
4. Verify download and preview behavior

## Expected results

- The backend export endpoint uses `/export/url`
- The frontend uses the shared export utility
- No ad hoc `blob` / `URL.createObjectURL` implementation is used
