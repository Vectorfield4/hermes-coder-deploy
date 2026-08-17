---
name: cleanup-branch
description: Deletes the local and remote branch.
---

# Cleanup Branch

1. Operate in the shared repo: `cd /workspace/<project>`.
2. Remove all worktrees for this branch first (git refuses to delete a branch that is checked out):
   ```
   git worktree list | grep "<branch>" | awk '{print $1}' | xargs -I {} git worktree remove {}
   ```
3. Get the branch name from the task metadata: `feature/<task_id>-<sanitized_title>`.
4. Switch to another branch (e.g., `main`).
5. Delete the local branch: `git branch -d feature/<task_id>-<sanitized_title>`.
6. Delete the remote branch: `git push origin --delete feature/<task_id>-<sanitized_title>`.
7. Add a task comment: "Branch deleted".
