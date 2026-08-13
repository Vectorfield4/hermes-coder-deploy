---
name: cleanup-branch
description: Deletes the local and remote branch.
---

# Cleanup Branch

1. Get the branch name from the task metadata: `feature/<task_id>-<sanitized_title>`.
2. Switch to another branch (e.g., `main`).
3. Delete the local branch: `git branch -d feature/<task_id>-<sanitized_title>`.
4. Delete the remote branch: `git push origin --delete feature/<task_id>-<sanitized_title>`.
5. Add a task comment: "Branch deleted".
