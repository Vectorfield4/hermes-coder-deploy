# Review Fix (`type == "review"`)

Loaded by `execute-task` when QA moved the task back to the coder for fixes. The task keeps `type: review` and carries `project`, `branch`, `pr_url`, and the rules info in metadata.

## Context

- QA's findings are in the task description or its latest comment (added by `execute-qa-task` with `--comment "QA found issues: <summary>"`).
- The same branch and PR are reused — fixes push new commits to the existing PR.

## Steps

1. **Load project rules** — run the load procedure from `references/memory.md`.

2. **Read the QA findings**
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract the issues from the description / latest comment.
   - If no findings can be extracted → `kanban_block` with "No QA findings in task".

3. **Apply fixes**
   - Check out `branch` in `/workspace/<project>`.
   - Fix each reported issue.
   - Follow the project `AGENTS.md` and the relevant `frontend-stack` reference via `skill_view("frontend-stack", "references/<file>.md")` when touching UI, data, or tests.
   - Call `kanban_heartbeat` before long operations.

4. **Validate**
   - Run project validation (lint / test / build) per cached rules or `AGENTS.md`.
   - If validation fails → fix and re-run; do not push broken code.

5. **Push the fixes**
   - Commit and push to the same `branch` (updates the existing PR).

6. **Hand back to QA**
   - Move the task to QA with priority so it is reviewed again:
     `kanban_move --task {{ env.HERMES_KANBAN_TASK }} --status ready --assignee qa --comment "Fixed: <summary of changes>"`
   - Do **not** `kanban_complete` — the task stays in the review loop until QA passes.
   - On failure to fix: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`
