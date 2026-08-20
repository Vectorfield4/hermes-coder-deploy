---
name: create-pr
description: Creates a commit, pushes the shared branch, and opens a Pull Request.
license: MIT
metadata:
  hermes:
    tags: [git, github, pr]
    related_skills: [execute-task]
---

# Create PR

Called by `execute-task` for the PR task (`pr_creation: true`). Validates, commits, pushes, opens PR.

## Steps

### 1. Input
- Receive `project` and `branch` from task metadata.
- Navigate to worktree: `cd /workspace/<project>-{{ env.HERMES_KANBAN_TASK }}`.

### 2. Validate
- Read validation commands from project context (AGENTS.md or cached rules).
- Run each command (e.g. `npm run lint`, `npm run test`).
- If any fails → return error to `execute-task`. Do not proceed.

### 3. Commit and push
- Ensure on correct branch. `git add . && git commit -m "Task #<task_id>: <description>"`.
- Load retry: `skill_view("create-pr", "references/retry.md")`.
- `git push origin <branch>`. Apply retry — transient errors retried; permanent fail immediately.

### 4. Create PR
- `gh pr create --title "Task #<task_id>: <description>" --body "<summary of changes>" --base dev`.
- Apply retry protocol.

### 5. Cleanup worktrees
- After PR created, clean up all worktrees for this branch:
  ```
  cd /workspace/<project>
  git worktree list | grep "<branch>" | awk '{print $1}' | xargs -I {} git worktree remove {}
  ```
- Do NOT delete `/workspace/<project>`.

### 6. Return
- Return PR number to `execute-task`.

## Verification
- `gh pr view` returns the PR URL (PR exists and is open).
- All worktrees for this branch are removed — `git worktree list | grep "<branch>"` returns empty.
- No files from this task remain outside the shared repo.
