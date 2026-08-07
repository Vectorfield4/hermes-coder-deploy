---
name: create-pr
description: Creates a commit, pushes the branch, and opens a Pull Request. Includes local validation.
license: MIT
metadata:
  hermes:
    tags: [git, github, pr]
    related_skills: [worker-loop]
---

# Create PR

## Overview
This skill is responsible for the final steps of the development process: validating the changes, committing them, pushing the branch, and creating a Pull Request. It is called by the `worker-loop` skill.

## When to Use
- This skill is called automatically by `worker-loop` after all subtasks are complete.
- **Do not use** this skill manually.

## Instructions

### 1. Input
- Receive `task_id`, `project`, and `changes_path` from `worker-loop`.
- The `changes_path` should contain all the generated files (code, content, etc.).

### 2. Local Validation
- Read the project context from memory (from `project-discover`).
- Extract validation commands from the project context (e.g., from `AGENTS.md` or `.hermes.md`).
- If no validation commands are found, skip validation with a warning.
- Execute each validation command (e.g., `npm run lint`, `npm run test`) in the project root.
- If any command fails:
  - Collect the error output.
  - Return an error to `worker-loop` with the details.
  - **Do not proceed** to commit.

### 3. Commit and Push
- If validation passes:
  - Switch to the project's main branch and pull latest changes.
  - Create a new branch: `<branch_prefix><task_id>` (branch prefix from project context).
  - Add all changes: `git add .`.
  - Commit: `git commit -m "Task #<task_id>: <description>"`.
  - Push: `git push origin <branch>`.

### 4. Create Pull Request
- Use `gh pr create` to open a PR.
- Title: `"Task #<task_id>: <description>"`.
- Body: Include a summary of changes (can be taken from the plan).
- Base branch: `main` or `master` (from project context).

### 5. Output
- Extract the PR number from the `gh` command output.
- Return success with the PR number to `worker-loop`.

## Tools
- `run_command(command, cwd)` (for git, gh, and validation commands)
- `memory_read` (for project context)

## Common Pitfalls
- **Skipping validation**: Always run validation if commands are defined.
- **Not pulling latest changes**: Always pull before creating a new branch.
- **Using wrong branch prefix**: Ensure the prefix is taken from the project context.

## Verification Checklist
- [ ] Validation commands are executed.
- [ ] All changes are committed.
- [ ] Branch is pushed.
- [ ] PR is created successfully.
- [ ] PR number is returned to `worker-loop`.