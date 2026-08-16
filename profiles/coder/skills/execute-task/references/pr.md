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

3. **Self-review the diff**
   - Run `git diff --name-only` to see what was changed.
   - For each changed file, verify it matches the project rules (from `references/memory.md`): code style, naming, structure, import conventions.
   - If a violation is found → fix it now (do not push a known violation to QA).
   - If all clean → proceed to PR creation.

4. **Create the pull request**
   - Call `skill_run(create-pr, project, branch)`.
   - This skill commits all changes, pushes the branch, and opens a PR.

5. **Hand off to QA review**
   - On success of `skill_run(create-pr, ...)`, create a QA review task (the QA loop picks it up by `assignee: qa`, `status: ready`):
     kanban_create(
     title: "QA Review: <branch>",
     description: "Review PR <pr_url> for project <project>",
     assignee: qa,
     status: ready,
     metadata: {
     project: "<project>",
     branch: "<branch>",
     pr_url: "<pr_url from create-pr output>",
     type: "review",
     parent_id: "{{ env.HERMES_KANBAN_TASK }}",
     chat_id: "<chat_id from the original task, if present>",
     rules_hash: "<rules_hash>",
     rules_keys_needed: ["validation-commands", "code-review-guidelines"]
     }
     )
   - Then complete the PR task:
     `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "PR #<number> created. Handed off to QA review."`
   - On failure of `create-pr`: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`
   - Code review is NOT done here — QA handles it via `execute-qa-task` → `review-and-deploy`. If QA finds issues it moves this review task back to the coder (see `references/review-fix.md`).
