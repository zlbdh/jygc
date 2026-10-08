---
scope: release-governance
owner: harness-core
applies_to:
  - all-releases
precedence: 3
last_reviewed: 2026-03-31
source_of_truth: control-repo
---

# Release gates

## 1. Minimum prerequisites for a release record

- All related business-repository PRs are available
- The change record has completed acceptance
- Configuration, script, and database impacts are listed
- Rollback steps are executable

## 2. Required release record contents

- Release ID
- Related `change-id`
- Affected repositories and branches/commits
- Database changes
- Configuration changes
- Release order
- Rollback steps
- Post-release monitoring points

## 3. Release blockers

- Not all affected repositories are verified
- Rollback steps are missing
- Critical interfaces or pages have not passed acceptance
- Only individual repositories were checked; the complete user workflow was not verified
- External facts lack sources or timestamps
