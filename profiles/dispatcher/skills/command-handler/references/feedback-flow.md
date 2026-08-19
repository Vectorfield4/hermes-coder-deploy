# Feedback Flow

Handles `/feedback [task_id] <text>` — processes user feedback. The LLM decides what action to take based on the feedback content.

## Input
- Raw message after `/feedback` (may or may not contain a task ID)
- `chat_id` — from `{{ env.TELEGRAM_CHAT_ID }}`

## Steps

1. **Parse input**
   - If message starts with a numeric ID → `task_id = <first token>`, `feedback_text = <rest>`.
   - Otherwise → `task_id = null`, `feedback_text = <entire message>`.

2. **Gather context**
   - If `task_id` is provided:
     - Fetch the task: `kanban_get_task(<task_id>)`.
     - Verify it belongs to the user: `metadata.chat_id == chat_id`. If not → reply: "Task #<id> does not belong to you."
     - Extract task context: title, description, status, type, project.
   - Get the user's recent tasks for broader context:
     `kanban_list_tasks(filter={metadata.chat_id: chat_id}, limit=5)`.

3. **Analyze and act**
   - Feed the LLM:
     - `feedback_text`
     - Task context (if task_id provided)
     - Recent tasks context
     - Instruction: "Analyze this feedback and take the appropriate action(s)."

   - The LLM decides what to do based on the feedback content. Possible actions:
     - **Create a refactoring task** — if the feedback describes something that needs to be changed, fixed, or improved in the codebase. Use the task-flow steps to create a `type: refactoring` task with `refactoring_target` extracted from the feedback.
     - **Store in memory** — if the feedback contains a pattern, preference, or rule to remember (e.g., "always use X", "never do Y", "I prefer Z"). Use `mcp_dense_mem_remember` with appropriate tags.
     - **Both** — if the feedback requires both a code change and memory storage.
     - **Neither** — if the feedback is purely informational or a compliment. Acknowledge it.

   - For memory writes (best-effort, never block):
     ```
     mcp_dense_mem_remember(
       evidence="<feedback summary>",
       tags=["project:<project>", "user-feedback", "<intent-tag>"],
       claims=["feedback-type:<type>"],
       confidence=medium
     )
     ```

4. **Reply**
   - Confirm what was done: "Got it. Created refactoring task #<id>." / "Noted. Stored in memory." / "Done. Created task #<id> and stored pattern in memory." / "Thanks for the feedback!"
   - If multiple actions were taken — list them all.
