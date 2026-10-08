# WEB-002 Product/service listing application workflow

## Type

- Documented regression case
- Planned automation: Playwright

## Goals

Verify the complete workflow from an enterprise listing application to platform approval.

## Inputs

- The enterprise portal has a service or product eligible for submission to the platform
- The platform has the corresponding approval entry point

## Steps

1. Submit a listing application in `web-portal`
2. Check whether `backend` creates an application record
3. View pending approvals in `admin-web`
4. Approve or reject the application
5. Return to `web-portal` to view the result

## Expected results

- Complete application data reaches the platform
- The approval result returns to the enterprise portal
- The rejection reason is visible
