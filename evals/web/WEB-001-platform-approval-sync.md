# WEB-001 Enterprise state synchronization after platform approval

## Type

- Documented regression case
- Planned automation: Playwright

## Goals

Verify the complete approval synchronization workflow across `admin-web -> backend -> web-portal`.

## Inputs

- The platform has an enterprise onboarding, service listing, or product listing record awaiting approval
- The enterprise portal has a corresponding details page or status list

## Steps

1. Approve the record in `admin-web`
2. Check whether `backend` completes the state change and synchronization
3. Sign in to `web-portal` and inspect the enterprise-side status display

## Expected results

- The platform approval status is persisted correctly
- Backend synchronization completes without errors
- The enterprise-side status, time, and processing result are consistent

## Risks

- Platform and enterprise status enums may differ
- Approval notes may fail to synchronize
