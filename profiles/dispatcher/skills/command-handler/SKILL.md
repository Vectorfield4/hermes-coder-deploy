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
3. Guardrails: reject the description if it is shorter than 10 characters or contains any of these tokens: `curl`, `wget`, `eval`, `exec`, `sudo`, `rm -rf`, `<!--`, `<script` — reply: "Description contains disallowed content."
4. Get the project list from memory: `memory_read(projects)`. If there are no projects → `project = "default"`.
5. Match the description against the projects:
- Search for keywords in the description: project names, their aliases, or the words "site", "project", "repo" + context.
- Use the LLM for semantic analysis: "Which project does this task belong to?"
- If a matching project is found → use it.
- If not found → `project = "default"`.
6. Determine the task type:
- If the description contains "bug", "fix", "error" → `type = "bugfix"`
- Otherwise → `type = "feature"`
7. Determine priority:
- If the description contains "urgent", "critical", "срочно", "быстро" → `priority = "urgent"`
- If the description contains "bug", "fix", "error" → `priority = "high"`
- Otherwise → `priority = "normal"`
8. Load retry protocol: `skill_view("command-handler", "references/retry.md")`.
9. Create a task in Kanban. Apply retry protocol to `kanban_create` — transient errors are retried; permanent errors fail immediately:
kanban_create(
title: "{{ description }}",
description: "{{ description }}",
assignee: orchestrator,
status: ready,
metadata: {
project: "{{ project }}",
type: "{{ type }}",
priority: "{{ priority }}",
chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
source: "telegram"
}
)
9. Reply: "✅ Task #<id> created for project **{{ project }}** and handed off to the orchestrator."

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

### 5. `/release <project>`
Creates a release task for QA that opens a PR from `dev` to `main`. The task is blocked until a human approves (HITL gate).

**Algorithm**:
1. Extract the project name or description from the message (everything after `/release`).
2. If the description is empty → reply: "Please provide a project name."
3. Determine the project (same logic as `/task`):
   - `memory_read(projects)`; if there are no projects → reply: "No projects registered. Use /project add first."
   - Match the description against the projects (keywords / LLM semantic analysis).
   - If a match is found → use it; otherwise reply: "Project not found. Use /project add to register it."
4. Create the release task in Kanban:
   kanban_create(
   title: "Release: {{ project }} (dev → main)",
   description: "Open a PR from dev to main for project {{ project }}. After PR creation, block for human approval before merging.",
   assignee: qa,
   status: ready,
   metadata: {
   project: "{{ project }}",
   type: "release",
   branch: "dev",
   target_branch: "main",
   chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
   source: "telegram"
   }
   )
5. Reply: "📦 Release task #<id> created for project **{{ project }}**. QA will open a PR from dev to main and wait for your approval."

> Note: `/release` does NOT deploy. It only creates a PR and waits for human approval. After merge, deploy separately with `/deploy-ftp`.

### 6. `/unblock <id>`
Unblocks a blocked task (HITL approval). The task must belong to the user (by `chat_id`).

**Algorithm**:
1. Verify the task exists and belongs to the user (by `chat_id` from metadata).
2. If the task is not blocked → reply: "Task #<id> is not blocked (status: <current_status>)."
3. If blocked → log the approval decision, then unblock:
   kanban_comment(
     task_id: "{{ id }}",
     body: "Approved by user in chat {{ env.TELEGRAM_CHAT_ID }} at {{ timestamp }}."
   )
   kanban_unblock(id)
4. Reply: "✅ Task #<id> unblocked. The agent will resume."

> Note: Use `/status` to see your blocked tasks and their IDs.

### 7. `/help`
Shows the list of available commands.

### 8. `/deploy-ftp <description>`
Creates a deploy task for QA that downloads the latest release zip from GitHub and uploads it to the server via FTP.

**Algorithm**:
1. Extract the description from the message (everything after `/deploy-ftp`).
2. If the description is empty → reply: "Please provide a project name or description."
3. Determine the project (same logic as `/task`):
   - `memory_read(projects)`; if there are no projects → `project = "default"`.
   - Match the description against the projects (keywords / LLM semantic analysis).
   - If a match is found → use it; otherwise `project = "default"`.
4. Create the deploy task in Kanban:
   kanban_create(
   title: "Deploy: {{ project }}",
   description: "Download the latest release zip from GitHub and upload to production via FTP for project {{ project }}.",
   assignee: qa,
   status: ready,
   metadata: {
   project: "{{ project }}",
   type: "deploy",
   chat_id: "{{ env.TELEGRAM_CHAT_ID }}",
   source: "telegram"
   }
   )
5. Reply: "🚀 Deploy task #<id> created for project **{{ project }}**."

> Note: `/deploy-ftp` downloads the latest GitHub Release zip and uploads it to the server via FTP. No human approval required — it's a mechanical operation. A release must exist first (run `/release` to create one).
