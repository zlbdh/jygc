# Minimum Command Contracts for the Seven Repositories

This document defines the minimum command interfaces the control repository can rely on when orchestrating AI and CI. Business repositories may extend them, but must meet this baseline.

## 1. Contract principles

- Define the smallest executable command first.
- Establish a working command before adding lint, typecheck, and smoke coverage.
- Actual business-repository script names are authoritative; this document provides a shared description.

## 2. `backend` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `mvn -version` | Check local Maven availability |
| Build | `mvn -pl <module> -am package -DskipTests` | Target the relevant microservice or module |
| Test | `mvn -pl <module> -am test` | Support at least module-level tests |
| Smoke | `mvn -pl <module> -am -Dtest=*Test test` | Current placeholder baseline |

- `backend` is a multimodule Maven project; specify the target module when executing commands.
- Add targeted tests for changes involving exports, idempotency, MQ, or Seata.

## 3. `web-portal` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `npm ci --ignore-scripts` | Prepare dependencies safely and minimize lockfile changes |
| Build | `npm run build:prod` | Currently known working baseline |
| Test | `npm run build:stage` | Initial minimum verification uses a build |
| Smoke | `npx playwright test` | Planned control-repository entry point |

Future additions:

- `npm run lint`
- `npm run typecheck`

## 4. `admin-web` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `npm ci --ignore-scripts` | Prepare dependencies safely and minimize lockfile changes |
| Build | `npm run build:prod` | Confirmed in the local repository |
| Test | `npm run build:stage` | Initial minimum verification uses a staging build |
| Smoke | `npx playwright test` | Planned control-repository entry point |

Current status: `baseline-ready`

Future additions:

- `lint`
- `typecheck`

## 5. `mobile-a` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `npm ci --ignore-scripts` | Initial minimum preparation; minimize lockfile changes |
| Build | `npm run start` | Verify React Native CLI availability; not an integration startup command |
| Test | `npm run test -- --watch=false` | Confirmed available |
| Check | `npm run lint` | Initial version uses lint in place of typecheck |
| Smoke | `maestro test .\\evals\\mobile` | Planned control-repository entry point |

Current status: `baseline-ready`

## 6. `mobile-b` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `npm ci --ignore-scripts` | Initial minimum preparation; minimize lockfile changes |
| Build | `npm run start` | Verify React Native CLI availability; not an integration startup command |
| Test | `npm run test -- --watch=false` | Confirmed available |
| Check | `npm run lint` | Initial version uses lint in place of typecheck |
| Smoke | `maestro test .\\evals\\mobile` | Planned control-repository entry point |

Current status: `baseline-ready`

## 7. `mobile-c` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `npm install --ignore-scripts` | Initial minimum preparation |
| Test | `npm run typecheck` | Placeholder baseline; confirm in the local repository |
| Smoke | `maestro test .\\evals\\mobile` | Planned control-repository entry point |

Current status: `missing-contract`

- This repository currently contains only requirements and a README, with no executable project.
- Complete the actual app project structure before adding it to the local baseline.

## 8. `miniapp` command contract

| Type | Minimum command | Notes |
|------|-----------------|-------|
| Bootstrap | `npm install --ignore-scripts` | If the repository uses a Node toolchain |
| Build | `npm run build` | Placeholder baseline; confirm in the local repository |
| Test | `npm run lint` | Placeholder baseline |
| Smoke | `Import check in WeChat DevTools` | Initial checks focus on environment and project configuration |

Current status: `missing-contract`

- This repository mainly contains HTML page prototypes and generation scripts.
- Complete standard miniapp project configuration before adding it to the local miniapp baseline.

## 9. Local verification layers

- `L1`: synchronization checks covering clones, remotes, branches, workspaces, and manifests
- `L2`: safe self-checks using only local commands with no side effects or low risk
- `L3`: local integration testing, excluded from control-repository gates in phase one

## 10. Contract implementation rules

- Keep `repos/repos.yaml` consistent with this document.
- When business-repository commands change, update this document and `repos.yaml` together.
- Do not use unregistered commands as formal control-repository gates.
- Repositories marked `missing-contract` must establish contracts before local integration or preproduction verification.
