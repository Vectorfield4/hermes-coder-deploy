---
name: resolve-merge-conflict
description: Automatically resolves merge conflicts.
---

# Resolve Merge Conflict

This skill works in both contexts: shared repo (`/workspace/<project>`) and worktree (`/workspace/<project>-<task_id>`). If called from a worktree, you are already on the correct branch — skip step 1.

1. Ensure you are on the PR branch (`feature/<task_id>-<sanitized_title>`). If in the shared repo, switch to it first.
2. Run `git fetch origin && git merge origin/<base_branch>`.
3. If there are no conflicts — success.
4. If there are conflicts:
   - Try to resolve them automatically with `git merge --strategy-option theirs`.
   - If that fails, identify the conflicting files.
   - Add a task comment with the list of files.
   - Return an error (the task moves to `ready`).
5. On successful resolution — commit and push.
