---
name: create-pr
description: Creates a commit, pushes the shared branch, and opens a Pull Request. Includes local validation.
license: MIT
metadata:
  hermes:
    tags: [git, github, pr]
    related_skills: [execute-task]
---

# Create PR

## Overview
This skill is responsible for the final steps of the development process: validating the changes, committing them, pushing the branch, and creating a Pull Request. It is called by `execute-task` for the PR task (`pr_creation: true`).

## When to Use
- This skill is called automatically by `execute-task` after all component sub-tasks are complete.
- **Do not use** this skill manually.

## Instructions

### 1. Input
- Receive `project` and `branch` — the shared branch `feature/<task_id>-<sanitized_title>` created by the orchestrator and already checked out in `/workspace/<project>`.

### 2. Local Validation
- Read the project context from memory (from `project-discover` or cached rules).
- Extract validation commands from the project context (e.g., from `AGENTS.md` or `.hermes.md`).
- If no validation commands are found, skip validation with a warning.
- Execute each validation command (e.g., `npm run lint`, `npm run test`) in the project root.
- If any command fails:
  - Collect the error output.
  - Return an error to `execute-task` with the details.
  - **Do not proceed** to commit.

### 3. Commit and Push
- Ensure the current branch is the given `branch` (checkout if needed).
- Add all changes: `git add .`.
- Commit: `git commit -m "Task #<task_id>: <description>"`.
- Load retry protocol: `skill_view("create-pr", "references/retry.md")`.
- Push with retry: `git push origin <branch>`. Apply the retry protocol — transient errors (timeout, network, 429, 5xx) are retried with exponential backoff; permanent errors (auth, 404) fail immediately.

### 4. Create Pull Request
- Load retry protocol: `skill_view("create-pr", "references/retry.md")`.
- Use `gh pr create` to open a PR. Apply the retry protocol to this call.
- Title: `"Task #<task_id>: <description>"`.
- Body: Include a summary of changes (can be taken from the plan).
- Base branch: `dev` (staging branch). Production release to `main` is handled separately via `/release`.

### 5. Output
- Extract the PR number from the `gh` command output.
- Return success with the PR number to `execute-task`.

## Tools
- `run_command(command, cwd)` (for git, gh, and validation commands)
- `memory_read` (for project context)

## Common Pitfalls
- **Skipping validation**: Always run validation if commands are defined.
- **Not pulling latest changes**: Always pull before creating a new branch.
- **Using the wrong branch**: Push to the shared branch from the task metadata, never create a new one.

## Verification Checklist
- [ ] Validation commands are executed.
- [ ] All changes are committed.
- [ ] Branch is pushed.
- [ ] PR is created successfully.
- [ ] PR number is returned to `execute-task`.
