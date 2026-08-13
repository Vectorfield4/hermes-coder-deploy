---
name: resolve-merge-conflict
description: Automatically resolves merge conflicts.
---

# Resolve Merge Conflict

1. Switch to the PR branch (`feature/<task_id>-<sanitized_title>`, from the task metadata).
2. Run `git fetch origin && git merge origin/<base_branch>`.
3. If there are no conflicts — success.
4. If there are conflicts:
   - Try to resolve them automatically with `git merge --strategy-option theirs`.
   - If that fails, identify the conflicting files.
   - Add a task comment with the list of files.
   - Return an error (the task moves to `ready`).
5. On successful resolution — commit and push.
