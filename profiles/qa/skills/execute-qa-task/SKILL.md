---
name: execute-qa-task
description: Executes a single QA task — dispatches to review-and-merge, release-to-main, or deploy-ftp based on task type, reports results, and handles the HITL approval flow.
metadata:
  hermes:
    tags: [qa, executor, review, release, deploy, hitl]
---

# Execute QA Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

### 0. Setup worktree
- Get the task: `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
- Extract `metadata.project` and `metadata.branch`.
- Skip worktree setup for `type: deploy` tasks.
- Create or reuse worktree:
  ```
  cd /workspace/<project>
  git worktree add /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} <branch>
  ```
- If worktree exists (resume) → use it.

### 1. Fetch the task
- Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
- Extract `title`, `description`, `metadata`. Ensure `ready` state.

### 2. Dispatch by task type
- **`type == "release"`** → `skill_run(release-to-main, project)`. Return.
- **`type == "deploy"`** → `skill_run(deploy-ftp, project)`. On success: `kanban_complete`. On failure: `kanban_block`. Return.
- **Otherwise (`type == "review"`)** → continue below.

### 3. Load project rules
- For each key in `metadata.rules_keys`:
  - Recall: `mcp_dense_mem_recall_memory(query="project rules for <project>: <key>", filter={tags: ["project-rules:<project>", "rules:<key>"]})`.
  - If found AND `rules_hash` matches → use it. Otherwise → read from `/workspace/<project>/AGENTS.md`.
- If `rules_keys` empty → load from `AGENTS.md` directly.

### 4. Pre-merge acceptance criteria check
- If `metadata.acceptance_criteria` exists:
  - **Automated** (mentions lint/test/build) → run validation. If fails → bounce to coder without merging.
  - **Manual** (mentions design/responsive) → note for post-merge, proceed with review.
- If missing → proceed.

### 5. Run the review pipeline
- `skill_run(review-and-merge, project, branch, pr_url, rules_context)`.
- On success → run `skill_run(pr-judge, pr_url, branch, project, rules_context)` for scoring.

### 6. Handle result

**SUCCESS:**
- `kanban_complete --comment "[outcome=success] QA passed. Merged to dev + Vercel staging. | judge_score=N"`
- Memory decision (best-effort, fire-and-forget):
  - Score ≥ 7 → `mcp_dense_mem_remember(evidence="<summary>", tags=["verified", "judge:<score>", "project:<project>"], confidence=high)`
  - Score ≤ 4 → retract positive evidence, store anti-pattern
  - Score 5–6 → no memory action

**NEEDS_FIXES:**
- Increment `metadata.review_iterations` by 1.
- Read `metadata.exploration_count` (default 0).
- **Terminal** (`exploration_count >= 2`): `kanban_block --reason "MAX_EXPLORATIONS_REACHED"`. Store terminal anti-pattern. Return.
- **Exploration** (`review_iterations >= 3` AND `exploration_count < 2`):
  - Store anti-pattern: `mcp_dense_mem_remember(evidence="EXPLORATION: Task '<title>' failed <N> iterations. Approach: <summary>. Orchestrator must re-decompose.", tags=["anti-pattern", "exploration", "project:<project>"], confidence=high)`
  - Move to orchestrator: `kanban_move --status ready --assignee orchestrator --comment "EXPLORATION TRIGGERED: <N> iterations failed. Re-decompose with different strategy."`
  - Update metadata: `exploration_triggered: true, exploration_count: <count+1>, priority_score: <score+5>`
  - Return.
- **Normal bounce** (`review_iterations < 3`):
  - `kanban_move --status ready --assignee coder --comment "QA found issues (iteration <N>): <summary>"`
  - Set `metadata.priority = "high"`, increment `priority_score`.

**FAILURE:**
- `kanban_block --reason "QA failed: <error details>"`.

### 7. Error handling
- `kanban_heartbeat` before long operations.
- On `skill_run` failure → `kanban_block` with details. Do not poll or loop.

## Workspace
- Worktree: `/workspace/<project>-<task_id>`. Shared repo: `/workspace/<project>`.
- `pr_url` required for review tasks. Release needs `project`. Deploy needs `project`.

## Verification
- Task status is one of: `done`, `blocked`, or `ready` (bounced back to coder).
- No task remains in `ready` after this skill completes — it was dispatched, completed, or blocked.
- Memory store fired at most once (on success with score) — no double-writes.
- If review iterations ≥ 3, task was moved to orchestrator (not back to coder).
