---
name: release-to-main
description: Opens a PR from dev to main, blocks for human approval, merges, then creates a GitHub Release with build artifacts. Handles idempotent resume after unblock.
license: MIT
metadata:
  hermes:
    tags: [qa, release, hitl, github]
    related_skills: [execute-qa-task, resolve-merge-conflict]
---

# Release to Main

## Overview
This skill is called by `execute-qa-task` for `type: release` tasks. It opens a PR from `dev` to `main`, blocks the task for human approval (HITL gate), merges after the human unblocks, then builds the project and creates a GitHub Release with the zip artifact.

**Note**: This skill operates in the QA worktree at `/workspace/<project>-<task_id>`. All git operations and builds happen in the worktree, ensuring full isolation from coder worktrees.

## When to Use
- This skill is called automatically by `execute-qa-task` for `type: release` tasks.
- Triggered by the `/release` Telegram command.
- **Do not use** for regular code review — use `review-and-merge` instead.

## Important: Idempotent Resume
This skill is designed to be called **multiple times** for the same task:
- **First call**: creates PR, posts context, blocks for approval.
- **Subsequent calls (after unblock)**: detects existing PR, skips to merge.

Always check for an existing PR before creating a new one.

## Instructions

### 1. Input
- Receive `task_id` from `execute-qa-task`.
- Extract `project` from task metadata.

### 2. Check for existing PR (idempotency guard)
- Before doing anything, check if a PR already exists:
  ```
  gh pr list --head dev --base main --json number,state,url,mergeable --repo <repo>
  ```
- If a PR exists and is `OPEN`:
  - This is a **resume after unblock**. Extract the PR number.
  - Skip to step 5 (merge after approval).
- If no PR exists → this is a fresh run. Continue to step 3.

### 3. Create PR from dev to main (fresh runs only)
- Ensure `dev` is up to date: `git fetch origin dev && git checkout dev && git pull origin dev`.
- Create the PR:
  ```
  gh pr create \
    --base main \
    --head dev \
    --title "Release: <project> (dev → main)" \
    --body "Release PR for <project>. Created by /release command. Merge after human approval."
  ```
- Extract the PR number from the output.

### 4. Prepare context and block for approval (fresh runs only)
- Generate a summary of changes: `git log main..dev --oneline --no-merges`.
- Generate a diff stat: `git diff main..dev --stat`.
- Check for security-sensitive changes: look for changes to `secrets/`, `docker-compose.yml`, `*.env*`, `Dockerfile`, or files containing `password`, `token`, `key`, `secret` in their names.
- Compose a comment with:
  - PR number and URL
  - Diff stat (files changed, insertions, deletions)
  - Security checklist (sensitive files changed or not)
  - List of commits since last release
- Post the comment via `kanban_comment`.
- Call `kanban_heartbeat(note="PR #<number> created, blocking for approval")`.
- Block for human approval:
  ```
  kanban_block(
    task_id="{{ env.HERMES_KANBAN_TASK }}",
    reason="approval-required: PR #<number> ready for merge dev→main. Review the PR and run /unblock <task_id> to approve.",
    kind="needs_input"
  )
  ```
- **Stop here.** The task is parked. The dispatcher will NOT spawn a worker for it.

### 5. Merge after approval (resume path)
- When the human runs `/unblock <task_id>`, the dispatcher respawns the worker.
- The worker starts at step 2, detects the existing PR, and jumps here.
- Call `kanban_heartbeat(note="resuming merge of PR #<number>")`.
- Verify the PR is mergeable: `gh pr view <number> --json mergeable,mergeStateStatus`.
- If the PR is no longer mergeable (conflict, closed, etc.) → block again with reason.
- If mergeable → merge: `gh pr merge <number> --squash --admin` (or without `--admin` if branch protection allows).
- On merge conflict:
  - Call `skill_run` with `resolve-merge-conflict`.
  - If resolved → proceed with merge.
  - If not → block with conflict details.

### 6. Build and create GitHub Release
- After successful merge, checkout main and pull: `git checkout main && git pull origin main`.
- Call `kanban_heartbeat(note="building project <project>")`.
- Run the project build commands (from project context / AGENTS.md, e.g. `npm install && npm run build`).
- On build failure → block with error details.
- Create a zip archive of the build output:
  ```
  cd <build_dir> && zip -r /tmp/<project>-<version>.zip .
  ```
- Determine the version tag: `git describe --tags --abbrev=0 2>/dev/null || echo "v0.1.0"` then increment patch (or use a version from project context if available).
- Call `kanban_heartbeat(note="creating GitHub release <tag>")`.
- Create a GitHub Release with the zip:
  ```
  gh release create <tag> /tmp/<project>-<version>.zip \
    --title "<project> <tag>" \
    --notes "Release <tag> — built from main after merge of dev branch."
  ```
- On release failure → block with error details.

### 7. Complete
- On successful release:
  - `kanban_complete` with summary: "Release <tag> created. Build artifacts uploaded. Deploy with /deploy-ftp."
  - Best-effort: store a verified experience record via `mcp_dense_mem_remember`.

## Tools
- `gh pr create`, `gh pr view`, `gh pr merge`, `gh pr list`
- `gh release create`
- `git log`, `git diff`, `git fetch`, `git describe`
- `skill_run(resolve-merge-conflict)`
- `kanban_block`, `kanban_comment`, `kanban_complete`, `kanban_heartbeat`
- `kanban_show` (to check prior runs and comments)
- `mcp_dense_mem_remember` (best-effort)

## Common Pitfalls
- **Creating duplicate PRs**: Always check `gh pr list` before `gh pr create`. The idempotency guard (step 2) prevents this.
- **Missing heartbeat**: Call `kanban_heartbeat` before every long operation (merge, build, release). The 4h stale timeout can reclaim a working task without heartbeats.
- **Losing context**: Always include PR URL, diff stat, and security checklist in the comment before blocking.
- **Not re-checking after unblock**: The PR state may have changed while blocked. Always verify mergeability before merging.
- **BLOCK_RECURRENCE_LIMIT**: If the task blocks again with the same reason after unblock, the recurrence counter increments. After 2 cycles, the task escalates to `triage`. Vary the block reason or resolve the underlying issue.

## Verification Checklist
- [ ] Checked for existing PR before creating (idempotency guard).
- [ ] PR from dev to main is created (fresh runs only).
- [ ] Context comment (diff stat, security checklist) is posted.
- [ ] Task is blocked for human approval with `kind=needs_input`.
- [ ] Heartbeat called before block.
- [ ] After unblock, PR mergeability is re-checked.
- [ ] Heartbeat called before merge.
- [ ] PR is merged successfully.
- [ ] Heartbeat called before build.
- [ ] Build succeeds.
- [ ] Zip archive is created.
- [ ] Heartbeat called before release.
- [ ] GitHub Release is created with the zip artifact.
- [ ] Task is completed with summary.
