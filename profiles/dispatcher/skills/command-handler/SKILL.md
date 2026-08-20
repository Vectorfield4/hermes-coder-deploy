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

## Commands

### `/task <description>`
Creates a task for the orchestrator. Load `skill_view("command-handler", "references/task-flow.md")` and follow it.

### `/ask <question>`
Answers a question via RAG recall. Load `skill_view("command-handler", "references/ask-flow.md")` and follow it.

### `/feedback [task_id] <text>`
Processes user feedback. Load `skill_view("command-handler", "references/feedback-flow.md")` and follow it.

### `/project add <url> [name]`
Registers a project and creates an init task for the coder.
1. Extract URL. If no name → derive from URL (last segment without `.git`).
2. Save to memory: `memory_write(projects, {name, url, added_at})`.
3. Create task:
   ```
   kanban_create(title: "Initialize project <name>", assignee: coder, status: ready,
     metadata: {project: "<name>", type: "init", chat_id, source: "telegram", repo_url})
   ```
4. Reply: "✅ Project **<name>** added. Task #<id> created for initialization."

### `/status [id]`
- With ID → `kanban_get_task(id)` → show status.
- Without ID → show user's last 5 tasks (by `chat_id`).

### `/cancel <id>`
Verify task belongs to user (by `chat_id`). If cancellable → `kanban_update(id, status: cancelled)`. Reply: "❌ Task #<id> cancelled."

### `/release <project>`
Creates a release task (dev → main PR, blocked for HITL approval).
1. Determine project: `memory_read(projects)` → match by keywords/LLM. If no match → reply "Project not found."
2. Create task:
   ```
   kanban_create(title: "Release: <project> (dev → main)", assignee: qa, status: ready,
     metadata: {project, type: "release", branch: "dev", target_branch: "main", chat_id, source: "telegram"})
   ```
3. Reply: "📦 Release task #<id> created. QA will open PR and wait for approval."

### `/unblock <id>`
HITL approval. Verify task belongs to user (by `chat_id`).
1. If not blocked → reply with current status.
2. If blocked → `kanban_comment(task_id, body: "Approved by user at <timestamp>.")` then `kanban_unblock(id)`.
3. Record approval signal (best-effort):
   ```
   mcp_dense_mem_remember(
     evidence="HITL approval: user <chat_id> approved <task_type> for <project>.",
     tags=["project:<project>", "hitl-approval", "<task_type>"], confidence=high)
   ```
4. Reply: "✅ Task #<id> unblocked."

### `/deploy-ftp <description>`
Creates an FTP deploy task.
1. Determine project: same as `/release`. If no match → `project = "default"`.
2. Create task:
   ```
   kanban_create(title: "Deploy: <project>", assignee: qa, status: ready,
     metadata: {project, type: "deploy", chat_id, source: "telegram"})
   ```
3. Reply: "🚀 Deploy task #<id> created."

### `/help`
Responds with:
```
/task <desc> — create a task
/ask <question> — RAG-powered answer
/feedback [task_id] <text> — give feedback
/project add <url> [name] — register a project
/status [id] — show task status
/cancel <id> — cancel a task
/release <project> — create release PR (dev → main)
/deploy-ftp <desc> — deploy via FTP
/unblock <id> — approve a blocked task
```

## Verification
- Every recognized command produced exactly one Telegram reply (no silent failures, no double replies).
- `/task` created exactly one kanban task with `assignee: orchestrator` and correct metadata.
- `/release` and `/deploy-ftp` created tasks with `assignee: qa`.
- `/cancel` and `/unblock` only succeeded on tasks belonging to the same `chat_id`.
- Unknown commands received a help-text reply (not ignored).
