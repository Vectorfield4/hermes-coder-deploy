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
   - First, try auto-resolution without a strategy option — Git will merge non-conflicting hunks automatically:
     ```
     git merge origin/<base_branch>
     ```
   - If conflicts remain, check which files are still conflicted: `git diff --name-only --diff-filter=U`.
   - For each conflicted file, inspect the conflict markers (`<<<<<<<`, `=======`, `>>>>>>>`) and resolve manually based on context:
     - If the conflict is in **your code** (the PR branch) — keep your version (you intentionally wrote it).
     - If the conflict is in **base branch code you didn't touch** — take theirs (it's an update you need).
     - If both sides changed the same lines — merge both changes logically.
   - If you cannot determine the correct resolution, abort the merge (`git merge --abort`) and return an error with the list of conflicted files.
   - **Never use `--strategy-option theirs`** — it blindly discards your changes.
5. On successful resolution — commit and push.
