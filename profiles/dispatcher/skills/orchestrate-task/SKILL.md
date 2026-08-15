---
name: orchestrate-task
description: Breaks down complex development tasks into parallel sub-tasks for coder agents, coordinating a single feature branch and final PR creation.
metadata:
  hermes:
    tags: [orchestrator, dispatcher, planning]
    related_skills: [project-discover]
---

# Orchestrate Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

### 1. Fetch the Task
- Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
- Extract `title`, `description`, and `metadata`.

### 2. Determine Project Context
- If `metadata.project` is set, use it.
- Otherwise, call `skill_run(project-discover, description)` to infer the project.
- Fallback: `default`.

### 3. Load and index project rules (once per project per git hash, cached in the RAG E-pool)
- Navigate to `/workspace/<project>`.
- Get current git commit hash: `git rev-parse HEAD` → `rules_hash`.
- Recall the rules index from the E-pool: `mcp_dense_mem_recall_memory(query="project rules for <project> (index)", filter={tags: ["project-rules:<project>", "rules-index"]} where the tool supports filters)`.
- If the recalled index record exists AND its `rules_hash` claim matches the current `rules_hash` → use the cached rules.
- Otherwise (missing or stale):
  - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` (if exist).
  - Use LLM to extract key rule sections (e.g., `ui-conventions`, `api-standards`, `testing-patterns`).
  - Store each section in the E-pool (best-effort): `mcp_dense_mem_remember(evidence=<section>, tags=["project-rules:<project>", "rules:<key>"], claims=[<rules_hash claim>], confidence=high)`.
  - Store the index record: `mcp_dense_mem_remember(evidence={"keys": [...], "rules_hash": "<rules_hash>"}, tags=["project-rules:<project>", "rules-index"], confidence=high)`.
  - If a stale index/rule record was recalled, retire it best-effort via `mcp_dense_mem_retract_evidence(...)` (the dispatcher owns these records).
  - Note: `remember` is asynchronous — freshly stored records become recallable after the verifier settles; the rules extracted from disk are already in this run's context, so planning does not depend on it.
- Graceful degradation: if any MCP call fails, extract the rules directly from disk and carry them in the decomposition context — planning must never block on the E-pool.
- Regardless of cache status, always pass the current `rules_hash` and `rules_keys_needed` to sub-tasks.

### 4. Recall related past experience (RAG E-pool)
- Call `mcp_dense_mem_recall_memory(query="<short goal summary of the task>")` to find similar past plans, decisions, or patterns for this project.
- Include the returned evidence contexts in the decomposition prompt as **advisory experience hints only** — never as authoritative requirements.
- Graceful degradation: if the MCP call fails or returns no results, continue without it. Planning must never block on the memory layer.
- Project rules (step 3) always take precedence over anything recalled from the E-pool.

### 5. Decompose the task
- Using LLM and the loaded context (keys), split the `description` into logical components:
- **UI** – pages, components, styling.
- **Content** – copy, static text, metadata.
- **Integration** – API calls, external services, data fetching.
- For each component, produce:
- `title` (short)
- `description` (detailed, copied from parent with specifics)
- `type` (ui / content / integration)
- `rules_keys_needed`: subset of keys from the index relevant to this component

### 6. Generate a Unique Feature Branch Name
- Create `feature/<task_id>-<sanitized_title>` (e.g., `feature/42-login-page`).  
- This branch will be used by all sub-tasks.

### 7. Create Sub-Tasks for Each Component
- For each component, call:
kanban_create(
title: "<title>",
description: "<description>",
assignee: coder,
status: ready,
metadata: {
project: "<project>",
branch: "<branch_name>",
type: "<component_type>",
parent_id: "{{ env.HERMES_KANBAN_TASK }}",
component: true,
rules_hash: "<rules_hash>",
rules_keys_needed: ["<key1>", "<key2>"]
}
)
- Store the returned IDs.

### 8. Create the Final PR Task
- This task will combine all changes and create a pull request.
- Call:
kanban_create(
title: "PR: <branch_name>",
description: "Aggregate changes from all components, validate, commit, push, and open PR.",
assignee: coder,
status: blocked,
metadata: {
project: "<project>",
branch: "<branch_name>",
parent_id: "{{ env.HERMES_KANBAN_TASK }}",
pr_creation: true,
rules_hash: "<rules_hash>",
rules_keys_needed: ["validation-commands", "code-review-guidelines"]
}
)
- Store its ID.

### 9. Link All Tasks as Children of the Parent
- For each sub-task ID (components + PR task), call:
kanban_link --parent {{ env.HERMES_KANBAN_TASK }} --child <subtask_id>

### 10. Set dependencies for the PR task
- The PR task must wait for all component tasks to finish.
- For each component task ID, call: kanban_link --parent <pr_task_id> --child <component_id> --block
- This ensures the PR task becomes `ready` only after all components are `done`.

### 11. Complete orchestration
- Close the parent task: kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "Orchestration complete. Decomposed into N components + 1 PR task."

### 12. Error handling
- If any `kanban_create` or `kanban_link` call fails, capture the error and call: kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error message>"
- Do not poll or loop – this skill runs once per task.