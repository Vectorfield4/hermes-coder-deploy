---
name: command-handler
description: Handles user commands from Telegram: /task, /status, /cancel, /project add, /help.
version: 1.0.0
author: Hermes Deploy
license: MIT
metadata:
  hermes:
    tags: [telegram, commands]
---

# Command Handler

## Overview
Processes incoming Telegram messages, parses commands, and interacts with the Kanban board and project management.

## Instructions

### 1. Get Command
- Extract the text of the message.
- Identify the command: `/task`, `/status`, `/cancel`, `/project add`, `/help`.

### 2. Handle `/task <description>`
- Check that the description is not empty.
- If empty: Reply "Please provide a task description."
- Otherwise:
  - Create a task in Kanban with status `ready`.
  - In `metadata`, store:
    - `chat_id` (from the message).
    - `project` (if specified via `@project`, otherwise use default).
    - `description` (the original text).
  - Reply: "Task #<id> created."

### 3. Handle `/project add <url>`
- Extract the repository URL.
- Clone the repository: `git clone <url> /workspace/<project_name>`.
- Check if `/workspace/<project_name>/package.json` exists (or other markers like `requirements.txt`, `go.mod`, etc.).
- Save project info to memory (`Project <project_name> added at /workspace/<project_name>`).
- If **project is initialized** (e.g., `package.json` exists):
  - Reply: "Project <project_name> added. You can now create development tasks."
  - **Do not** create any task — the project is ready.
- If **project is NOT initialized** (no `package.json`, etc.):
  - Create a task in Kanban with:
    - Title: "Initialize project <project_name>"
    - Description: "Initialize project structure, install dependencies, and set up CI."
    - Metadata: `type = "init"`, `project = <project_name>`, `chat_id = ...`
  - Reply: "Project <project_name> added. Task #<id> created to initialize the project and set up CI."

### 4. Handle `/status <id>`
- Read task from Kanban by ID.
- Reply with current status and latest comments.

### 5. Handle `/cancel <id>`
- Verify `chat_id` matches.
- Update task status to `blocked` with comment "Cancelled by user."

### 6. Handle `/help`
- List available commands.

## Tools
- `kanban_create`, `kanban_read`, `kanban_update`
- `telegram_send_message`
- `git clone`
- `memory_write`
- `file_exists(path)` (to check for `package.json`)

## Common Pitfalls
- **Not checking if project exists**: Always verify the clone succeeded.
- **Not storing `chat_id`**: Required for notifications and cancelation.
- **Not handling invalid URLs**: Validate before cloning.