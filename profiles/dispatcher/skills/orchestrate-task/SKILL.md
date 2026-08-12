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

### 3. Load and index project rules (once per project per git hash)
- Navigate to `/workspace/<project>`.
- Get current git commit hash: `git rev-parse HEAD` → `rules_hash`.
- Try to read `memory_read(project_{project}_rules_index)`.
- If index exists and its `hash` matches current `rules_hash`, use it.
- Otherwise:
  - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` (if exist).
  - Use LLM to extract key rule sections (e.g., `ui-conventions`, `api-standards`, `testing-patterns`).
  - For each section, store as separate memory entry: memory_replace(project_{project}rules{key}, <section_content>, metadata: {hash: <rules_hash>})
  - Store the index: memory_replace(project_{project}_rules_index, {
keys: [<list of extracted keys>],
hash: <rules_hash>,
updated_at: <timestamp>
})

### 4. Decompose the task
- Using LLM and the loaded context (keys), split the `description` into logical components:
- **UI** – pages, components, styling.
- **Content** – copy, static text, metadata.
- **Integration** – API calls, external services, data fetching.
- For each component, produce:
- `title` (short)
- `description` (detailed, copied from parent with specifics)
- `type` (ui / content / integration)
- `rules_keys_needed`: subset of keys from the index relevant to this component

### 5. Generate a Unique Feature Branch Name
- Create `feature/<task_id>-<sanitized_title>` (e.g., `feature/42-login-page`).  
- This branch will be used by all sub-tasks.

### 6. Create Sub-Tasks for Each Component
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

### 7. Create the Final PR Task
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

### 8. Link All Tasks as Children of the Parent
- For each sub-task ID (components + PR task), call:
kanban_link --parent {{ env.HERMES_KANBAN_TASK }} --child <subtask_id>

### 9. Set dependencies for the PR task
- The PR task must wait for all component tasks to finish.
- For each component task ID, call: kanban_link --parent <pr_task_id> --child <component_id> --block
- This ensures the PR task becomes `ready` only after all components are `done`.

### 10. Complete orchestration
- Close the parent task: kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "Orchestration complete. Decomposed into N components + 1 PR task."

### 11. Error handling
- If any `kanban_create` or `kanban_link` call fails, capture the error and call: kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error message>"
- Do not poll or loop – this skill runs once per task.