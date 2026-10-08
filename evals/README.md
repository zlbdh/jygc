# Golden regression suite

This directory stores high-value cross-repository regression cases. The initial version combines documented regression cases with reserved plans for automation.

## Directory conventions

- `web/`: Web regression tests, preferably Playwright
- `api/`: Backend API and critical-workflow smoke tests
- `mobile/`: Mobile regression tests, preferably Maestro

## Initial golden workflows

1. Enterprise state synchronization after platform approval
2. Product/service listing application workflow
3. Routing platform orders to enterprises
4. Enterprise to-do items are visible in the app
5. Export workflow
6. Duplicate submission / idempotency workflow

## Current status

- The initial version may contain only directories and a case inventory
- Each case must specify inputs, steps, and expected results
- Attach future automation scripts directly to these cases using the same naming scheme
