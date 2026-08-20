# Task Creation Flow

Handles `/task <description>` — creates a Kanban task for the orchestrator.

## Input
- `description` — text after `/task`
- `chat_id` — from `{{ env.TELEGRAM_CHAT_ID }}`

## Steps

1. **Validate description**
   - Empty → "Please provide a task description."
   - < 10 characters → "Description is too short (min 10 characters)."
   - Contains disallowed tokens (`curl`, `wget`, `eval`, `exec`, `sudo`, `rm -rf`, `<!--`, `<script`) → "Description contains disallowed content."

2. **Detect project**
   - `memory_read(projects)`. If none → `project = "default"`.
   - Match by keywords or LLM semantic analysis. If no match → `"default"`.

3. **Classify type and priority**
   - Type: "refactor"/"рефактор"/"restructure" → `refactoring`. "bug"/"fix"/"error" → `bugfix`. Otherwise → `feature`.
   - Priority: "urgent"/"critical"/"срочно" → `urgent`. "bug"/"fix"/"error" → `high`. Otherwise → `normal`.

4. **Compute priority_score** (age=0 at creation)
   - `type_weight`: bugfix=4, release=4, deploy/review=3, feature/ui/integration/refactoring=2, content/init=1.
   - `priority_score = type_weight` + urgent bonus (+2) or high bonus (+1).

5. **Build metadata**
   - Base: `project`, `type`, `priority`, `priority_score`, `review_iterations: 0`, `chat_id`, `source: "telegram"`.
   - If refactoring → add `refactoring_target` (extracted from description by LLM).

6. **Create task**
   - Load retry: `skill_view("command-handler", "references/retry.md")`.
   - `kanban_create(title: "<description>", assignee: orchestrator, status: ready, metadata: {<built>})`.

7. **Reply**
   - `✅ Task #<id> created for project **<project>** (score: <priority_score>).`
   - If refactoring → append: "Target: <refactoring_target>"
