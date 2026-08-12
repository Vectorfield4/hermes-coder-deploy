---
name: execute-qa-task
description: Executes a single QA task – runs review-and-deploy, reports results, and moves the task back to coder if issues are found.
metadata:
  hermes:
    tags: [qa, executor, review]
---

# Execute QA Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

1. **Fetch the task**
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract `title`, `description`, `metadata`.
   - Required metadata: `project`, `branch`, `pr_url` (if PR already exists). If missing, block with reason.
   - Ensure the task is in `ready` state (the dispatcher should have moved it there when all components were done).

2. **Load project rules from memory (cached)**
   - Extract from `metadata`:
     - `rules_keys` – list of rule keys needed (same as in execute-task, e.g., `["testing-patterns", "review-standards"]`)
     - `rules_hash` – version stamp from orchestrator
   - For each key in `rules_keys`:
     - Call `memory_read(project_rules_{project}_{key})`.
     - If not found OR hash mismatch:
       - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md`.
       - Extract the relevant section for this key.
       - Call `memory_replace(project_rules_{project}_{key}, <extracted_rule>, metadata: {hash: <new_hash>})`.
       - Use the rule in current context.
   - If `rules_keys` is empty → load only essential QA guidelines from memory or fallback to generic.

3. **Run the QA pipeline**
   - **Step 3.1**: Call `skill_discover("review-and-deploy")` to find the appropriate skill.
   - If found: call `skill_run(review-and-deploy, project, branch, pr_url, rules_context)`.
   - If not found: fallback to a generic QA skill (or block with "Missing QA skill").
   - The `review-and-deploy` skill should:
     - Run automated tests (linting, unit, integration).
     - Perform code review (static analysis, security checks, adherence to guidelines).
     - Attempt deployment to staging (if applicable).
     - Return a report with status (success / failure / needs-fixes).

4. **Handle the result**
   - **If `review-and-deploy` returns SUCCESS**:
     - `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "QA passed. Ready for merge."`
     - Optionally, notify via Telegram (but that's out of scope).
   - **If `review-and-deploy` returns NEEDS_FIXES** (minor issues, comments):
     - Move the task back to `ready` with `assignee: coder` so that the developer can fix the issues.
     - Use `kanban_move --task {{ env.HERMES_KANBAN_TASK }} --status ready --assignee coder --comment "QA found issues: <summary>"`.
   - **If `review-and-deploy` returns FAILURE** (critical errors, deployment failure, CI crash):
     - `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "QA failed: <error details>"`.
     - Optionally, notify the team.

5. **Heartbeat and error handling**
   - Call `kanban_heartbeat` before each long-running operation (especially before `review-and-deploy`).
   - If any `skill_run` fails, capture the error and call `kanban_block` with details.
   - Do not poll or loop – this skill runs once per task.

## Important Notes
- This skill assumes the workspace is available at `/workspace/<project>`.
- The `pr_url` should be present in metadata (set by the PR creation task). If missing, block with "No PR URL provided".
- The `review-and-deploy` skill is expected to return a structured result – you may need to standardize its output format (e.g., a JSON with `status`, `message`, `details`).
- If the task has no `rules_keys`, you can still run a generic QA, but it's highly recommended to include them for context-aware reviews.

## Memory Schema (same as execute-task)
- Index: `project_rules_{project}_index` – contains keys and hash.
- Individual rules: `project_rules_{project}_{key}` – cached content.

## Comparison with old qa-loop
- Removed internal polling – now triggered by `hermes kanban work --loop`.
- Replaced `kanban_list` with single-task processing.
- Added memory-cached rules for context.
- Added `skill_discover` for flexibility.
- Added clear branching for success/needs-fixes/failure.