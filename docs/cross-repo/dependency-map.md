# Repository Dependency Map

## 1. Repository roles

- `backend`: primary backend business logic and source of truth for state
- `web-portal`: enterprise desktop web portal
- `admin-web`: platform-wide administration
- `mobile-a`: enterprise mobile app
- `mobile-b`: merchant app
- `mobile-c`: staff app, currently governed as a prototype repository
- `miniapp`: consumer miniapp, currently governed as a prototype repository

## 2. Main dependencies

```text
web-portal ----\
admin-web ---\
mobile-a ---\
mobile-b ----> backend
mobile-c ---/
miniapp -----/
```

- `backend` is currently the primary source of truth for most cross-repository state.
- `admin-web` handles platform-wide approvals, oversight, routing, and control.
- `web-portal`, `mobile-a`, and `mobile-b` primarily consume and operate business capabilities.
- The business roles of `mobile-c` and `miniapp` are defined, but their projects are not yet established.

## 3. Invariants at this stage

- Cross-repository state transitions must have an implementation in `backend`.
- Platform approval workflows must explicitly pass through `admin-web`.
- Frontend and mobile displays do not replace authoritative backend state.
- Prototype repositories must not be treated as release-ready repositories.
