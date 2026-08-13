# PR Creation (`pr_creation == true`)

Loaded by `execute-task` after the project rules have been loaded (see `references/memory.md`).

## Steps

1. **Ensure all components are done**
   - Since this task is `blocked` until all components are done, it becomes `ready` automatically.
   - Verify that the branch contains changes.

2. **Validate the code**
   - Run project-specific validation (linting, tests).
   - Use validation commands from cached rules (see `references/memory.md`) or from `AGENTS.md`.
   - Call `kanban_heartbeat` before validation.

3. **Create the pull request**
   - Call `skill_run(create-pr, project, branch)`.
   - This skill commits all changes, pushes the branch, and opens a PR.

4. **Finalize the PR task**
   - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "PR #<number> created."`
   - On failure: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`
   - Note: code review is not done here — it is handled by QA via `execute-qa-task` → `review-and-deploy`.
