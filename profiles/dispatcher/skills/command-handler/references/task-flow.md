# Task Creation Flow

Handles `/task <description>` — creates a Kanban task for the orchestrator.

## Input
- `description` — text after `/task`
- `chat_id` — from `{{ env.TELEGRAM_CHAT_ID }}`

## Steps

1. **Validate description**
   - If empty → reply: "Please provide a task description."
   - If shorter than 10 characters → reply: "Description is too short (min 10 characters)."
   - If contains disallowed tokens (`curl`, `wget`, `eval`, `exec`, `sudo`, `rm -rf`, `<!--`, `<script`) → reply: "Description contains disallowed content."

2. **Detect project**
   - Get project list from memory: `memory_read(projects)`.
   - If no projects → `project = "default"`.
   - Match description against projects:
     - Search for keywords: project names, aliases, or words "site", "project", "repo" + context.
     - Use LLM for semantic analysis: "Which project does this task belong to?"
     - If match found → use it.
     - If not found → `project = "default"`.

3. **Classify type and priority**
   - Type:
     - Description contains "refactor", "рефактор", "restructure", "reorganize" → `type = "refactoring"`
     - Description contains "bug", "fix", "error" → `type = "bugfix"`
     - Otherwise → `type = "feature"`
   - Priority:
     - Contains "urgent", "critical", "срочно", "быстро" → `priority = "urgent"`
     - Contains "bug", "fix", "error" → `priority = "high"`
     - Otherwise → `priority = "normal"`

4. **Compute priority_score** (age=0 at creation)
   - `type_weight`: bugfix=4, release=4, deploy=3, review=3, feature=2, ui=2, refactoring=2, content=1, integration=2, init=1
   - `age_urgency = 0`, `iteration_penalty = 0`, `dependency_bonus = 0`
   - `priority_score = type_weight`
   - If `priority == "urgent"` → +2 bonus
   - If `priority == "high"` → +1 bonus

5. **Build metadata**
   - Base: `project`, `type`, `priority`, `priority_score`, `review_iterations: 0`, `chat_id`, `source: "telegram"`
   - If `type == "refactoring"` — add `refactoring_target: "<what specifically needs to change, extracted from description>"` (LLM extracts the target: file, module, pattern, or behavior to refactor)

6. **Create Kanban task**
   - Load retry protocol: `skill_view("command-handler", "references/retry.md")`.
   - Apply retry protocol to `kanban_create`:
     ```
     kanban_create(
       title: "<description>",
       description: "<description>",
       assignee: orchestrator,
       status: ready,
       metadata: { <built metadata> }
     )
     ```

7. **Reply**
   - `✅ Task #<id> created for project **<project>** (score: <priority_score>) and handed off to the orchestrator.`
   - If `type == "refactoring"` → append: "Target: <refactoring_target>"
