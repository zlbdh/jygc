# {{CHANGE_ID}} / {{REPO_ID}} Task card

## Repository information

- Repository: `{{REPO_NAME}}`
- Repository ID: `{{REPO_ID}}`
- Technology stack: `{{STACK}}`
- Default execution agent: `{{DEFAULT_OWNER}}`

## Execution status references

- Branch: register in `execution.yaml`
- Worktree: register in `execution.yaml`
- Lock state: register in `execution.yaml`
- Actual code-editing tasks require an isolated, clean worktree. Do not execute directly in the main repository's dirty working tree.

## Inputs

-

## Outputs

-

## Change boundaries

-

## Prohibited changes

-

## Repository verification commands

- Build:
- Test:
- Smoke:

## Writeback requirements

- Repository workers write back only to `verification/workers/{{REPO_ID}}.md`
- Do not directly modify `verification/result.md`
- verification-agent consolidates the primary verification conclusion in `verification/result.md`
