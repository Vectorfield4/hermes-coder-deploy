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
- Pull latest changes: `git pull origin dev` (or `main` if `dev` does not exist).
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
- **Recall anti-patterns** for this project: `mcp_dense_mem_recall_memory(query="<goal>", filter={tags: ["anti-pattern", "project:<project>"]})`. If recalled, these are known failures — do NOT repeat the same decomposition approach.
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
- `type` (ui / content / integration / 3d)
- `rules_keys_needed`: subset of keys from the index relevant to this component
- `acceptance_criteria`: 2-5 concrete, testable conditions that must be true when the component is done (e.g. "component renders without errors", "passes lint", "matches design spec"). These are the checklist QA will verify.
- **Self-check before creating sub-tasks**: for each component, verify its `acceptance_criteria` against:
  1. The original task `description` — every criterion must trace to a stated requirement, not be invented.
  2. The project's validation commands (from `AGENTS.md`) — at least one criterion must be verifiable via lint/test/build, not only by LLM judgment.
  3. Feasibility — drop any criterion that cannot be checked in the available toolset (no "user loves the design" — that's not testable).
  If a criterion fails these checks, rewrite or drop it before including it in `metadata`. Bad criteria propagate to QA and waste review cycles.
- **If `metadata.exploration_triggered == true`**: this task has been bounced back after ≥3 failed review iterations. The previous decomposition did not work. You MUST:
  1. **Recall exploration anti-patterns** (best-effort):
     ```
     mcp_dense_mem_recall_memory(
       query="exploration anti-pattern for <project>: <task title>",
       filter={tags: ["anti-pattern", "exploration", "project:<project>"]}
     )
     ```
     These records describe *what approach was tried and why it failed*. Treat them as **authoritative avoidance constraints** — do NOT repeat the same decomposition strategy.
     On failure or empty results, continue without them.
  2. Read the previous component structure (from the task's child links or comments).
  3. Analyze what went wrong using QA findings + recalled anti-patterns.
  4. Re-decompose with a **different strategy**: fewer components, simpler scope, different tech choices, or a completely different approach. **The new decomposition must be provably different from the anti-patterns recalled.**
  5. Add a comment: `[exploration] Re-decomposed with alternative strategy: <what changed and why>. Anti-patterns avoided: <summary of recalled anti-patterns>`.
  6. Preserve the original `project`, `branch`, and `rules_hash` — the new components continue on the same branch.

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
rules_keys_needed: ["<key1>", "<key2>"],
acceptance_criteria: ["<criterion 1>", "<criterion 2>"]
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
- Close the parent task: kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] Orchestration complete. Decomposed into N components + 1 PR task. | steps=<N> | retries=<N>"

### 12. Error handling
- If any `kanban_create` or `kanban_link` call fails, capture the error and call: kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error message>"
- Do not poll or loop – this skill runs once per task.