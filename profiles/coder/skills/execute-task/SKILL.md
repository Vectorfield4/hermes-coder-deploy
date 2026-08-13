---
name: execute-task
description: Executes a single development sub-task (UI, content, integration), initializes a new project (`type: init`), or aggregates changes and creates a PR.
metadata:
  hermes:
    tags: [coder, executor]
---

# Execute Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Dispatch

1. **Fetch the task**
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract `title`, `description`, and `metadata`.
   - Required metadata: `project`. If missing, block with reason.
   - `branch` / `repo_url` are required only for the relevant flow (see step 2).

2. **Determine task type** from `metadata`:
   - `type == "init"` → load `skill_view("execute-task", "references/init.md")` and follow it. Project rules are not loaded — the project may not exist yet.
   - `component == true` → load `skill_view("execute-task", "references/memory.md")` and run its load procedure, then load `skill_view("execute-task", "references/component.md")` and follow it.
   - `pr_creation == true` → load `skill_view("execute-task", "references/memory.md")` and run its load procedure, then load `skill_view("execute-task", "references/pr.md")` and follow it.
   - `type == "review"` → load `skill_view("execute-task", "references/memory.md")` and run its load procedure, then load `skill_view("execute-task", "references/review-fix.md")` and follow it. This flow is entered when QA moved the task back for fixes; `project`, `branch`, and `pr_url` come from task metadata.
   - Otherwise → `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "Unknown task type"`.

## Conventions (all flows)

- Call `kanban_heartbeat` before each `skill_run` and before long-running operations (validation).
- On failure of any step: capture the error and `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`.
- On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "<summary>"` — see the loaded flow for the exact comment.
- The workspace is at `/workspace/<project>`; the branch is shared across all component tasks.
- Start the coder agent with `--skip_context_files` to avoid overloading the global memory.
