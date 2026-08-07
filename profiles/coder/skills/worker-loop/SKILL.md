---
name: worker-loop
description: Main development loop. Captures ready tasks, routes init tasks to project-init + setup-ci, and orchestrates full development pipeline for regular tasks.
license: MIT
metadata:
  hermes:
    tags: [core, development, orchestration]
    related_skills: [project-init, setup-ci, ui-architect, ui-implementer, content-strategist, integration-specialist, create-pr, project-discover]
---

# Worker Loop

## Overview
This is the main loop for the coder profile. It runs continuously, captures tasks from the Kanban board, and routes them based on task type:
- **Init tasks** (`type == "init"`): calls `project-init` + `setup-ci` to bootstrap a new project.
- **Development tasks** (default): orchestrates the full development pipeline: planning → execution → validation → PR creation.

## When to Use
- This skill runs automatically in the background.
- It is triggered by the `hermes gateway run --profile coder` command.
- **Do not use** this skill manually.

---

## Instructions

### 1. Task Capture
- Every 30 seconds, call `kanban_list` with filter `status=ready`.
- If a task is found:
  - Capture it: update status to `coding`, set `assigned_to = coder`.
  - Update `heartbeat_at`.
  - Extract `task_id`, `description`, `project`, and `metadata`.

### 2. Task Routing
- Inspect `metadata.type`:
  - If `type == "init"` → go to **Init Pipeline** (step 3).
  - Else (default, or `type == "development"`) → go to **Development Pipeline** (step 4).

---

### 3. Init Pipeline (for `type == "init"`)
- **Purpose**: Bootstrap a new project that lacks basic structure (e.g., no `package.json`).
- **Steps**:
  1. Call `skill_run(project-init, project_name)`.
     - This skill creates `package.json`, installs dependencies, sets up linting, etc.
  2. If `project-init` succeeds, call `skill_run(setup-ci, project_name)`.
     - This skill adds GitHub Actions workflow for CI.
  3. If both succeed:
     - Update task status to `done`.
     - Add comment: "Project <project_name> initialized and CI configured."
  4. If any step fails:
     - Update task status to `blocked` with error details.
     - Optionally, leave in `coding` for retry (with retry count logic).
- **Exit** (do not proceed to Development Pipeline).

---

### 4. Development Pipeline (default)
- **Purpose**: Execute a full development task from planning to PR.
- **Steps**:

#### 4.1. Project Context
- If `project` is not set in metadata, try to determine it from the description or use the default project.
- Call `skill_run(project-discover, project_name)` to load project context (tech stack, rules, validation commands) into memory.

#### 4.2. Planning (Built-in)
- Analyze the task `description`.
- Break it down into subtasks. Identify the type of work required:
  - **UI**: New pages, components, styling.
  - **Content**: Text, copy, metadata.
  - **Integration**: API calls, external services.
  - **Other**: Any other specific requirements.
- Create a simple plan (e.g., a list of steps) and store it in memory or a temporary file (e.g., `/workspace/<project>/changes/plan.md`).

#### 4.3. Execution of Subtasks
- For each subtask in the plan:
  - Based on the subtask type, call the appropriate specialized skill using `skill_run`:
    - `ui-architect` → for UI design.
    - `ui-implementer` → for UI implementation.
    - `content-strategist` → for content generation.
    - `integration-specialist` → for integrations.
  - Each skill should save its output to the workspace (e.g., `/workspace/<project>/changes/`).
  - After each subtask, check if the task is still in `coding` status (to avoid conflicts if another agent took over).

#### 4.4. PR Creation
- After all subtasks are complete, call `skill_run(create-pr, task_id, project, changes_path)`.
- The `create-pr` skill will:
  - Run local validation (linting, tests) using commands from project context.
  - If validation passes: commit changes, push branch, create PR.
  - If validation fails: return error with details.

#### 4.5. Completion
- If `create-pr` succeeds:
  - Update task status to `review`.
  - Add comment: "PR #<number> created."
- If `create-pr` fails:
  - Update task status to `blocked` (or `coding` with retry logic).
  - Add comment with error details.
- If any step fails critically (e.g., cannot read repository, missing permissions):
  - Update task status to `blocked` with an error description.

---

### 5. Heartbeat
- Update `heartbeat_at` at the start of each loop iteration (before capturing a task) to avoid zombie detection.

### 6. Error Handling
- If any skill call fails, capture the error message.
- For **init tasks**: update status to `blocked` (or `coding` with retry).
- For **development tasks**: update status to `blocked` with error details.
- Always add a comment with the error to help debugging.

---

## Tools
- `kanban_list`, `kanban_start`, `kanban_update`, `kanban_comment`
- `skill_run(skill_name, params)`
- `memory_read`, `memory_write`

## Common Pitfalls
- **Not checking task type**: Always inspect `metadata.type` before routing.
- **Not updating `heartbeat_at`**: Update at the start of each loop.
- **Not checking task status before each step**: Always verify the task is still in `coding` before proceeding.
- **Overcomplicating the plan**: Keep the plan simple and actionable.

## Verification Checklist
- [ ] `type == "init"` tasks are routed to `project-init` + `setup-ci`.
- [ ] Development tasks follow the full pipeline: planning → execution → `create-pr`.
- [ ] Project context is loaded before planning.
- [ ] Specialized skills are called correctly for each subtask.
- [ ] `create-pr` is called as the final step for development tasks.
- [ ] Task status is updated correctly on success or failure.
- [ ] Heartbeat is updated at the start of each loop.