---
name: command-handler
description: Handles Telegram commands and creates Kanban tasks with automatic project detection
metadata:
  hermes:
    tags: [telegram, gateway, dispatcher]
---

# Command Handler

## Input
- Telegram message (`{{ env.TELEGRAM_MESSAGE }}`)
- Chat ID (`{{ env.TELEGRAM_CHAT_ID }}`)

## Available Commands

### 1. `/task <description>`
Creates a task for the orchestrator with automatic project detection.

**Algorithm**:
1. Extract the description from the message (everything after `/task`).
2. If the description is empty → reply: "Please provide a task description."
3. Get the project list from memory: `memory_read(projects)`. If there are no projects → `project = "default"`.
4. Match the description against the projects:
- Search for keywords in the description: project names, their aliases, or the words "site", "project", "repo" + context.
- Use the LLM for semantic analysis: "Which project does this task belong to?"
- If a matching project is found → use it.
- If not found → `project = "default"`.
5. Determine the task type:
- If the description contains "bug", "fix", "error" → `type = "bugfix"`
- Otherwise → `type = "feature"`
6. Create a task in Kanban:
kanban_create(
title: "{{ description }}",
description: "{{ description }}",
assignee: orchestrator,
status: ready,
metadata: {
project: "{{ project }}",
type: "{{ type }}",
chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
source: "telegram"
}
)
7. Reply: "✅ Task #<id> created for project **{{ project }}** and handed off to the orchestrator."

### 2. `/project add <url> [name]`
Adds a new project and creates an initialization task **directly for the coder**.

**Algorithm**:
1. Extract the repository URL.
2. If a name is provided → use it, otherwise extract it from the URL (last part without `.git`).
3. Save the project to memory:
memory_write(projects, {
name: "{{ project_name }}",
url: "{{ url }}",
added_at: "{{ timestamp }}"
})
4. Create an initialization task **directly for the coder** (bypassing the orchestrator):
kanban_create(
title: "Initialize project {{ project_name }}",
description: "Initialize project structure, install dependencies, and set up CI",
assignee: coder,
status: ready,
metadata: {
project: "{{ project_name }}",
type: "init",
chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
source: "telegram",
repo_url: "{{ url }}"
}
)
5. Reply: "✅ Project **{{ project_name }}** added. Created task #<id> for initialization (assignee: coder)."

### 3. `/status [id]`
Shows the status of a task or a list of all tasks.

**Algorithm**:
- If an ID is provided → show the status of that task: `kanban_get_task(id)`
- If no ID → show the user's last 5 tasks (by `chat_id` from metadata).

### 4. `/cancel <id>`
Cancels a task (moves it to `cancelled`).

**Algorithm**:
1. Verify the task exists and belongs to the user (by `chat_id`).
2. If it can be cancelled → `kanban_update(id, status: cancelled)`.
3. Reply: "❌ Task #<id> cancelled."

### 5. `/help`
Shows the list of available commands.

### 6. `/deploy <description>`
Creates a deploy task for QA that runs the production FTP deploy on the current `main`.

**Algorithm**:
1. Extract the description from the message (everything after `/deploy`).
2. If the description is empty → reply: "Please provide a project name or description."
3. Determine the project (same logic as `/task`):
   - `memory_read(projects)`; if there are no projects → `project = "default"`.
   - Match the description against the projects (keywords / LLM semantic analysis).
   - If a match is found → use it; otherwise `project = "default"`.
4. Create the deploy task in Kanban:
kanban_create(
title: "Deploy: {{ project }}",
description: "Run the production FTP deploy for project {{ project }} on branch main.",
assignee: qa,
status: ready,
metadata: {
project: "{{ project }}",
type: "deploy",
branch: "main",
chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
source: "telegram"
}
)
5. Reply: "🚀 Deploy task #<id> created for project **{{ project }}**."

> Note: merges to `main` already deploy to Vercel staging automatically. `/deploy` runs the FTP deploy (production) on demand.
