---
name: execute-qa-task
description: Executes a single QA task – dispatches deploy tasks to deploy-ftp, otherwise runs review-and-deploy, reports results, and moves the task back to coder if issues are found.
metadata:
  hermes:
    tags: [qa, executor, review, deploy]
---

# Execute QA Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

1. **Fetch the task**
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract `title`, `description`, `metadata`.
   - Ensure the task is in `ready` state.

2. **Dispatch by task type**
   - If `metadata.type == "deploy"` → run the FTP deploy flow:
     - Required metadata: `project`. If missing, block with reason.
     - Call `skill_discover("deploy-ftp")`; if found, call `skill_run(deploy-ftp, project)`.
     - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "FTP deploy completed for {{ project }}."`
     - On failure: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "FTP deploy failed: <error details>"`
     - **Return here** — do not run the review flow.
   - Otherwise (default, `type == "review"`) → continue with the review pipeline below.

## Review Pipeline

3. **Load project rules from memory (cached)**
   - Extract from `metadata`:
     - `rules_keys` – list of rule keys needed (`["testing-patterns", "review-standards", ..]`)
     - `rules_hash` – version stamp from orchestrator
   - For each key in `rules_keys`:
     - Call `memory_read(project_rules_{project}_{key})`.
     - If not found OR hash mismatch:
       - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md`.
       - Extract the relevant section for this key.
       - Call `memory_replace(project_rules_{project}_{key}, <extracted_rule>, metadata: {hash: <new_hash>})`.
       - Use the rule in current context.
   - If `rules_keys` is empty → load only essential QA guidelines from memory or fallback to generic.

4. **Run the QA pipeline**
   - **Step 4.1**: Call `skill_discover("review-and-deploy")` to find the appropriate skill.
   - If found: call `skill_run(review-and-deploy, project, branch, pr_url, rules_context)`.
   - If not found: fallback to a generic QA skill (or block with "Missing QA skill").
   - The `review-and-deploy` skill should:
     - Run automated tests (linting, unit, integration).
     - Perform code review (static analysis, security checks, adherence to guidelines).
     - Merge the PR to `main` and deploy to Vercel staging.
     - Return a report with status (success / failure / needs-fixes).

5. **Handle the result**
   - **If `review-and-deploy` returns SUCCESS**:
     - `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "QA passed. Merged to main and deployed to Vercel staging."`
     - Optionally, notify via Telegram (but that's out of scope).
   - **If `review-and-deploy` returns NEEDS_FIXES** (minor issues, comments):
      - Move the task back to the coder as **high priority** so the coder loop picks it up next:
      - `kanban_move --task {{ env.HERMES_KANBAN_TASK }} --status ready --assignee coder --comment "QA found issues: <summary>"` and keep `metadata.type == "review"` (so the coder's `execute-task` routes it to the fix flow) plus `metadata.priority = "high"` where the board supports it.
   - **If `review-and-deploy` returns FAILURE** (critical errors, deployment failure, CI crash):
     - `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "QA failed: <error details>"`.
     - Optionally, notify the team.

6. **Heartbeat and error handling**
   - Call `kanban_heartbeat` before each long-running operation (especially before `review-and-deploy` or `deploy-ftp`).
   - If any `skill_run` fails, capture the error and call `kanban_block` with details.
   - Do not poll or loop – this skill runs once per task.

## Important Notes
- Workspace is available at `/workspace/<project>`.
- For review tasks the `pr_url` should be present in metadata. If missing, block with "No PR URL provided".
- Deploy tasks (`type: deploy`) only need `project` — they deploy `main` and never touch a PR.
- The `review-and-deploy` skill is expected to return a structured result – you may need to standardize its output format (e.g., a JSON with `status`, `message`, `details`).
- If the task has no `rules_keys`, you can still run a generic QA, but it's highly recommended to include them for context-aware reviews.

## Memory Schema (same as execute-task, see `profiles/coder/skills/execute-task/references/memory.md`)
- Index: `project_rules_{project}_index` – contains keys and hash.
- Individual rules: `project_rules_{project}_{key}` – cached content.