---
name: review-and-deploy
description: Checks CI status, merges the PR, and deploys the changes.
license: MIT
metadata:
  hermes:
    tags: [qa, ci, deploy]
    related_skills: [execute-qa-task, resolve-merge-conflict, deploy-ftp]
---

# Review and Deploy

## Overview
This skill is called by `execute-qa-task` to verify the CI status of a PR, merge it, and deploy the changes. It assumes that CI is already set up for the project.

## When to Use
- This skill is called automatically by `execute-qa-task` for tasks in `ready` status.
- **Do not use** this skill manually.

## Instructions

### 1. Input
- Receive `task_id` from `execute-qa-task`.
- Extract `project` and `pr_number` from task metadata.

### 2. Get PR Number
- If `pr_number` is not in metadata, use `gh pr list --head <branch>` to find it.
- The branch name follows the shared convention `feature/<task_id>-<sanitized_title>` (from task metadata).

### 3. Check CI Status
- Use `gh pr view <pr> --json statusCheckRollup` to get CI status.
- If CI is still running, wait and retry every 30 seconds (max 10 minutes).
- If CI fails:
  - Update task status to `ready` with a comment containing the error log.
  - **Stop here**.

### 4. Merge PR
- If CI passes (or if there is no CI, which should not happen), merge the PR: `gh pr merge --squash`.
- If there is a merge conflict:
  - Call `skill_run` with `resolve-merge-conflict`.
  - If the conflict is resolved, proceed with the merge.
  - If not, update task status to `ready` with a comment about the conflict.

### 5. Deploy
- After a successful merge, call `skill_run` with `deploy-ftp`.
- If deployment succeeds:
  - Update task status to `done`.
  - Add a comment: "Deployed successfully."
- If deployment fails:
  - Update task status to `blocked` with an error description.

## Tools
- `gh pr view`, `gh pr merge`
- `skill_run(resolve-merge-conflict)`, `skill_run(deploy-ftp)`
- `memory_read` (for project context)

## Common Pitfalls
- **Assuming CI is always present**: If CI is missing, the project was not set up correctly. This should be handled at the project addition stage.
- **Not handling timeouts**: Always enforce a maximum wait time for CI.

## Verification Checklist
- [ ] PR number is retrieved.
- [ ] CI status is checked and passes.
- [ ] PR is merged successfully.
- [ ] Deployment is completed.
- [ ] Task status is updated correctly.