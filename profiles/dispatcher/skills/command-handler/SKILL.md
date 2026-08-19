---
name: command-handler
description: Handles Telegram commands: task creation, Q&A, feedback, project management, releases, and deploys
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

**Flow:** Load `skill_view("command-handler", "references/task-flow.md")` and follow it.

### 1a. `/ask <question>`
Answers a question using RAG recall. No task is created.

**Flow:** Load `skill_view("command-handler", "references/ask-flow.md")` and follow it.

### 1b. `/feedback [task_id] <text>`
Processes user feedback. The LLM decides what action to take (create refactoring task, store in memory, or both).

**Flow:** Load `skill_view("command-handler", "references/feedback-flow.md")` and follow it.

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
4. Record the approval as a positive training signal in the E-pool (best-effort, never block on failure):
   - Read the task to extract context: `kanban_get_task(id)` → get `metadata.project`, `metadata.type`, and the most recent kanban comment (which contains the diff stat and security checklist from the QA agent).
   - Write the signal:
     ```
     mcp_dense_mem_remember(
       evidence="HITL approval: user <chat_id> approved <task_type> for <project> at <timestamp>. Context: <summary from QA comment — diff stat, security checklist pass/fail>.",
       tags=["project:<project>", "hitl-approval", "<task_type>"],
       claims=["human-verified:true", "approval-type:<task_type>"],
       confidence=high
     )
     ```
   - Ignore errors: if the memory write fails, the unblock still stands.
5. Reply: "✅ Task #<id> unblocked. The agent will resume."

> Note: Use `/status` to see your blocked tasks and their IDs.

### 7. `/help`
Shows the list of available commands:
- `/task <description>` — create a task for the orchestrator
- `/ask <question>` — ask a question (RAG-powered answer)
- `/feedback [task_id] <text>` — give feedback (may create a task or update memory)
- `/project add <url> [name]` — register a project
- `/status [id]` — show task status
- `/cancel <id>` — cancel a task
- `/release <project>` — create a release PR (dev → main)
- `/deploy-ftp <description>` — deploy via FTP
- `/unblock <id>` — approve a blocked task

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
