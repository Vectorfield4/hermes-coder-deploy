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
     - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] FTP deploy completed for {{ project }}. | steps=<N> | retries=<N>"`
     - On failure: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "FTP deploy failed: <error details>"`
     - **Return here** — do not run the review flow.
   - Otherwise (default, `type == "review"`) → continue with the review pipeline below.

## Review Pipeline

3. **Load project rules from the RAG cache (E-pool)**
   - Extract from `metadata`:
     - `rules_keys` – list of rule keys needed (`["testing-patterns", "review-standards", ..]`)
     - `rules_hash` – version stamp from orchestrator
   - For each key in `rules_keys`:
     - Recall the rule record: `mcp_dense_mem_recall_memory(query="project rules for <project>: <key>", filter={tags: ["project-rules:<project>", "rules:<key>"]} where the tool supports filters)`.
     - If found AND its `rules_hash` claim equals `rules_hash` → use it.
     - If not found OR mismatch → read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` and extract the relevant section directly (deterministic fallback).
     - Do **not** write rule records from the QA profile (rules are owned by the orchestrator).
   - If `rules_keys` is empty → load essential QA guidelines from `AGENTS.md` or fallback to generic.

4. **Run the QA pipeline**
   - **Step 4.1**: Call `skill_discover("review-and-deploy")` to find the appropriate skill.
   - If found: call `skill_run(review-and-deploy, project, branch, pr_url, rules_context)`.
   - If not found: fallback to a generic QA skill (or block with "Missing QA skill").
   - **Step 4.2 (optional, best-effort)**: call `mcp_dense_mem_recall_memory(query="<review focus, e.g. known pitfalls for <project> or the component type>")` and consider past failure patterns during the review. On failure or empty results, continue without it.
   - The `review-and-deploy` skill should:
     - Run automated tests (linting, unit, integration).
     - Perform code review (static analysis, security checks, adherence to guidelines).
     - Merge the PR to `main` and deploy to Vercel staging.
     - Return a report with status (success / failure / needs-fixes).

5. **Handle the result**
   - **Acceptance criteria check (if `metadata.acceptance_criteria` exists)**:
     - Compare each criterion against the codebase/output. If any criterion is not met, treat the result as NEEDS_FIXES (append unmet criteria to the summary).
   - **If `review-and-deploy` returns SUCCESS**:
      - `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] QA passed. Merged to main and deployed to Vercel staging. | steps=<N> | retries=<N>"`
      - Then, best-effort, store a VERIFIED experience summary via `mcp_dense_mem_remember(...)` (concise evidence of what passed review + key decisions; mark high confidence / "verified by QA"). Fire-and-forget — never block completion on memory writes.
      - Optionally, notify via Telegram (but that's out of scope).
   - **If `review-and-deploy` returns NEEDS_FIXES** (minor issues, comments):
       - Move the task back to the coder as **high priority** so the coder loop picks it up next:
       - `kanban_move --task {{ env.HERMES_KANBAN_TASK }} --status ready --assignee coder --comment "QA found issues: <summary>"` and keep `metadata.type == "review"` (so the coder's `execute-task` routes it to the fix flow) plus `metadata.priority = "high"` where the board supports it.
       - If a wrong pattern was likely replayed from the E-pool, say so in the comment so the coder can trace and retire its own evidence during the fix loop (see `execute-task` reference `rag.md`). You can only correct/retract evidence your own QA profile submitted; coder-owned evidence is fixed by the coder.
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

## Rules cache (project rules via RAG E-pool, same as `execute-task` → `references/memory.md`)
- Rules are stored by the orchestrator (dispatcher profile) in dense-mem, tagged `project-rules:<project>` (+ `rules:<key>` per rule, `rules-index` for the index record).
- `rules_hash` in task metadata invalidates the cache; disk `AGENTS.md` / `SOUL.md` is the deterministic fallback.
- Tagged rules records are authoritative over untagged experience records.

## Experience memory (E-pool via dense-mem)
- Tools are exposed as `mcp_dense_mem_*` (server `dense_mem` in `config.yaml`).
- Tagged rules records (`project-rules:<project>`) are authoritative; untagged experience records are advisory only.
- All memory calls are best-effort: on failure, continue the task without memory.
- Ownership: dense-mem lets a profile correct/retract only its own submitted evidence.