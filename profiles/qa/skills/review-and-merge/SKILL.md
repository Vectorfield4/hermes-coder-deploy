---
name: review-and-merge
description: Checks CI status, merges the PR to dev, and triggers Vercel staging deployment.
license: MIT
metadata:
  hermes:
    tags: [qa, ci, review, staging]
    related_skills: [execute-qa-task, resolve-merge-conflict, deploy-vercel]
---

# Review and Merge

Called by `execute-qa-task` for `type: review` tasks. Verifies CI, merges to `dev`, deploys to Vercel staging.

## Steps

### 1. Input
- Receive `task_id`. Extract `project` and `pr_number` from metadata.
- If `pr_number` missing → `gh pr list --head <branch>` to find it.

### 2. Check CI status
- `gh pr view <pr> --json statusCheckRollup`.
- If running → wait and retry every 30s (max 10 min).
- If failed → bounce to coder with error log. Stop.

### 3. Merge to dev
- `gh pr merge --squash --base dev`.
- If merge conflict → `skill_run(resolve-merge-conflict)`. If resolved → proceed. If not → bounce to coder.

### 4. Deploy to Vercel staging
- `skill_run(deploy-vercel)`.
- Success → `kanban_update(status: done)` + comment: "Merged to dev. Staging: <url>".
- Failure → `kanban_update(status: blocked)` with error.
