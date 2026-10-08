# Memory Governance

## 1. Core principles

The example product control plane uses layered memory governance rather than a universal memory database:

- Repository artifacts are long-term memory.
- Threads and conversation history are short-term memory.
- MCP provides external, read-only context.
- Skills are reusable execution procedures.
- `reports/` contains verification evidence.
- `postmortem.md` records failures and initiates improvements.

The criterion is simple: **facts needed for releases, acceptance, and reconstruction must be available in the repository.**

## 2. Memory layers

| Layer | Source of truth | Current problem | Governance approach |
|-------|-----------------|-----------------|---------------------|
| Global memory | `docs/`, `standards/`, `templates/`, `AGENTS.md` | Rules exist but are not always read first | Use `AGENTS.md` as an index; record facts in repository files |
| Repository/module memory | Business-repository READMEs, `.agent/rules`, examples | Scattered, uneven, and difficult to locate | The control repository indexes and routes without copying business facts |
| Change memory | `changes/<change-id>/` | Structure exists but does not yet cover all actual requests | Preserve complete lifecycle files for every request |
| Cross-repository memory | `impact.yaml`, `docs/cross-repo/` | Dependency maps and workflow indexes are new | Maintain shared workflow, dependency, and contract indexes |
| Verification memory | `reports/`, `verification/result.md` | Technical reports can be confused with business acceptance | Reports represent technical checks; record acceptance in the change record |
| Failure memory | `postmortem.md`, regression lists, rule updates | Rework lessons can remain in conversations | Produce at least one improvement after each incident or rework cycle |
| External context | MCP, development/test systems | Facts may lack provenance | Include sources and timestamps for all external facts |

## 3. What must be written back

Do not leave these items only in threads or verbal communication:

- Request goals and success criteria
- Cross-repository impact and dependency order
- Execution owners, write boundaries, branches, worktrees, and locks
- Repository verification and cross-repository acceptance results
- Release records and rollback steps
- Incident postmortems and improvements

Default destinations:

- Requirements: `brief.md`
- Impact: `impact.yaml`
- Execution status: `execution.yaml`
- Design: `design.md`
- Acceptance: `acceptance.md`
- Verification: `verification/result.md`
- Release: `release/` or an instance of the release template
- Postmortem: `postmortem.md`

## 4. What is not an authoritative system fact

These may provide leads, but cannot directly support release decisions:

- Verbal conclusions in conversations
- Screenshots without sources and timestamps
- Claims of local testing without corresponding commits or branches
- Temporary agent reasoning that was not saved
- MCP results that were not saved

## 5. Responsibilities of `execution.yaml`

`execution.yaml` is the key machine-readable memory file at this stage. It records:

- Current stage: `stage`
- Current stage owner: `stage_owner`
- Repository owners: `repo_owners`
- Write boundaries: `write_scopes`
- Dependencies: `depends_on`
- Branches: `branch`
- Worktrees: `worktree`
- Locks: `lock_state`
- Snapshot time: `snapshot_at`

It is the authoritative record for concurrent execution and reconstruction, rather than a conversation summary.

## 6. V2 evolution boundaries

Future additions may include:

- Persistent thread storage
- Automated indexing
- MCP snapshot caching
- Automatic links between threads, PRs, releases, and change records

Repository artifacts remain the final source of truth in V2 as well.
