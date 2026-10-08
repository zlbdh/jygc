# Complete Practical Template

## 1. How to use this template

This template explains how the control repository and business repositories should organize artifacts when adding a cross-repository module.
Example module: **add staff scheduling and attendance**.

Goals:

- Enterprises can create staff schedules
- Staff can view schedules and clock in/out
- Staff can appeal attendance exceptions
- Enterprises can review appeals
- The platform can view oversight data

## 2. Example directory structure

```text
changes/CHG-2026-0002-staff-scheduling-attendance/
  brief.md
  impact.yaml
  execution.yaml
  design.md
  acceptance.md
  tasks/
    backend.md
    web-portal.md
    admin-web.md
    mobile-a.md
    mobile-c.md
  verification/
    result.md
  postmortem.md
```

## 3. Example `brief.md`

```md
# CHG-2026-0002 - Add staff scheduling and attendance

## Business goals
- Enterprises can create staff schedules
- Staff can view schedules and clock in/out
- Staff can appeal attendance exceptions
- Enterprises can review exception appeals
- The platform can view oversight data

## User roles
- Enterprise administrators
- Staff
- Platform oversight staff

## Success criteria
- The enterprise administration portal can create, edit, and deactivate schedules
- Staff can view their own schedules and clock in/out in the staff app
- Attendance records are saved to the backend and can be queried
- Exception appeals enter an approval workflow
- The platform can view schedule and exception statistics

## Non-goals
- Intelligent schedule recommendations are out of scope for this phase
- Automatic payroll settlement is out of scope for this phase

## Risk notes
- Cross-platform state synchronization
- Location-based attendance and exception appeals
- Permission boundaries between platform and enterprise users
```

## 4. Example `impact.yaml`

```yaml
change_id: "CHG-2026-0002-staff-scheduling-attendance"
title: "Add staff scheduling and attendance"
is_cross_repo: true
affected_repos:
  - id: backend
    modules: [schedule, attendance, appeal, approval]
  - id: web-portal
    modules: [schedule-admin, attendance-review]
  - id: admin-web
    modules: [attendance-supervision]
  - id: mobile-a
    modules: [attendance-approval-mobile]
  - id: mobile-c
    modules: [my-schedule, checkin-checkout, appeal]
affected_interfaces:
  - POST /schedule/create
  - POST /attendance/check-in
  - POST /attendance/check-out
  - POST /attendance/appeal
  - POST /attendance/appeal/approve
affected_tables:
  - schedule_plan
  - attendance_record
  - attendance_appeal
affected_configs:
  - geo-checkin-policy
dependency_order:
  - backend
  - web-portal
  - mobile-c
  - mobile-a
  - admin-web
notes:
  - "Implement the backend first and keep frontend/backend fields consistent."
```

## 5. Example `execution.yaml`

```yaml
change_id: "CHG-2026-0002-staff-scheduling-attendance"
title: "Add staff scheduling and attendance"
stage: planned
stage_owner: impact-design-agent
repo_owners:
  backend: backend-exec-agent
  web-portal: web-exec-agent
  admin-web: admin-web-exec-agent
  mobile-a: mobile-a-exec-agent
  mobile-c: mobile-c-planning-agent
write_scopes:
  control_repo:
    owner: impact-design-agent
    files:
      - brief.md
      - impact.yaml
      - execution.yaml
      - design.md
      - acceptance.md
      - verification/result.md
      - postmortem.md
  business_repos:
    backend: []
    web-portal: []
    admin-web: []
    mobile-a: []
    mobile-c: []
depends_on:
  - workspace-baseline-workflow
  - change-intake-workflow
branch:
  backend: "codex/CHG-2026-0002-hd-attendance"
  web-portal: "codex/CHG-2026-0002-qd-attendance"
  admin-web: "codex/CHG-2026-0002-admin-web-attendance"
  mobile-a: "codex/CHG-2026-0002-mobile-a-attendance"
  mobile-c: "codex/CHG-2026-0002-mobile-c-attendance"
worktree:
  backend: "D:\\workspace\\worktrees\\chg-0002-hd"
  web-portal: "D:\\workspace\\worktrees\\chg-0002-qd"
  admin-web: "D:\\workspace\\worktrees\\chg-0002-admin-web"
  mobile-a: "D:\\workspace\\worktrees\\chg-0002-mobile-a"
  mobile-c: "D:\\workspace\\worktrees\\chg-0002-mobile-c"
lock_state:
  control_repo: unlocked
  business_repos:
    backend: unlocked
    web-portal: unlocked
    admin-web: unlocked
    mobile-a: unlocked
    mobile-c: unlocked
snapshot_at: "2026-03-31T21:00:00+08:00"
```

## 6. Example `design.md`

```md
# CHG-2026-0002 Design notes

## Goals
- Add staff scheduling and attendance

## Business workflows
- Enterprise creates a schedule
- Staff view their schedules
- Staff clock in/out
- The system records attendance
- Submit an appeal for an exception
- Enterprise approval
- Platform views oversight data

## Data flow / state flow
- Schedule master data lives in backend
- Attendance master data lives in backend
- Approval-state master data lives in backend
- web-portal / mobile-a / mobile-c / admin-web only consume state or trigger state changes

## Interface and data changes
- Scheduling APIs
- Attendance APIs
- Appeal and approval APIs
- Tables for schedules, attendance, and appeals

## Cross-repository dependency order
- backend
- web-portal
- mobile-c
- mobile-a
- admin-web

## Failure handling
- Repeated clock-in requests must be idempotent
- Reject out-of-range locations or route them to an exception appeal
- Approval failures must not lose attendance audit records

## Compatibility strategy
- Phase one adds capabilities without replacing the existing work-order system

## Release and rollback considerations
- Release the backend first, followed by web and mobile clients

## Needs confirmation
- Is deferred upload of offline attendance required?
```

## 7. Example task cards

### 7.1 `tasks/backend.md`

```md
# CHG-2026-0002 / backend Task card

## Inputs
- Business requirements for scheduling, attendance, appeals, and approvals

## Outputs
- Scheduling APIs
- Clock-in/clock-out APIs
- Appeal and approval APIs
- Table structures and state flows

## Change boundaries
- Only scheduling, attendance, and appeal modules

## Prohibited changes
- Do not change unrelated order, commerce, or finance logic

## Repository verification commands
- Build: mvn package -DskipTests
- Test: mvn test
- Smoke: mvn -Dtest=*Attendance* test
```

### 7.2 `tasks/web-portal.md`

```md
## Outputs
- Schedule management page
- Attendance records page
- Exception appeal approval page
```

### 7.3 `tasks/admin-web.md`

```md
## Outputs
- Platform oversight statistics page
- Exception appeal viewer
```

### 7.4 `tasks/mobile-a.md`

```md
## Outputs
- View schedules in the enterprise mobile app
- Approve attendance exceptions in the enterprise mobile app
```

### 7.5 `tasks/mobile-c.md`

```md
## Outputs
- My schedule page
- Clock-in/clock-out page
- Exception appeal page
```

## 8. Example `acceptance.md`

```md
# CHG-2026-0002 Acceptance checklist

1. Create a schedule in the enterprise administration portal
   Expected: the schedule is created successfully and appears in the staff app

2. Staff view their schedule
   Expected: staff see only their own schedules with the correct status

3. Staff clock in
   Expected: an attendance record is created with clocked-in status

4. Staff submit an exception appeal
   Expected: an appeal is created and awaits enterprise approval

5. Enterprise reviews the appeal
   Expected: the approval result synchronizes to the staff and oversight interfaces

6. Platform views oversight data
   Expected: schedule, attendance, and exception-appeal statistics are visible
```

## 9. Example `verification/result.md`

```md
# CHG-2026-0002 Verification results

## Execution summary
- Current status: Pending integration testing
- Snapshot source: Local baseline + repository verification
- Snapshot time: 2026-03-31 21:00:00

## Repository verification results
| Repository | Command | Result | Notes |
|------|----------|------|------|
| backend | mvn test | PASS | Scheduling and attendance tests passed |
| web-portal | npm run build | PASS | Page build passed |
| admin-web | npm run build | PASS | Platform oversight page build passed |
| mobile-a | npm run lint | PASS | Enterprise mobile rules passed |
| mobile-c | npm run lint | PASS | Basic project scaffolding has been added to the prototype repository |

## Cross-repository acceptance results
| Step | Acceptance item | Result | Notes |
|------|--------|------|------|
| 1 | Enterprise creates a schedule | PASS | |
| 2 | Staff view their schedule | PASS | |
| 3 | Staff clock in | PASS | |
| 4 | Exception appeal | PASS | |
| 5 | Enterprise approval | PASS | |
| 6 | View platform oversight | PASS | |

## Remaining risks
- Location exception scenarios still need boundary tests
```

## 10. Example release order

Recommended order:

1. `backend`
2. `admin-web`
3. `web-portal`
4. `mobile-a`
5. `mobile-c`

Reasons:

- Frontend and mobile releases require the backend APIs first
- Platform oversight depends on backend state
- Both enterprise and staff clients depend on the final APIs and state flows

## 11. Example postmortem feedback

If staff clock in successfully after release but the enterprise display does not synchronize, the postmortem must produce at least one of these actions:

- Add a cross-repository state synchronization rule to the control repository
- Add a golden regression case verifying enterprise visibility after clock-in
- Document the root cause and feedback action in `postmortem.md`
- Add a task-specific skill or script to check synchronization fields

## 12. Usage recommendations

- Copy this template first, then adapt it to the specific module
- Do not leave all fields empty and immediately begin business-repository development
- If a prototype repository lacks an executable project, explicitly mark it as planning-stage in `impact.yaml` and `execution.yaml`
