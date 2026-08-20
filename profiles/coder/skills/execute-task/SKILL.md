---
name: execute-task
description: "Executes a single development sub-task (UI, content, integration), initializes a new project (type: init), or aggregates changes and creates a PR."
metadata:
  hermes:
    tags: [coder, executor]
---

# Execute Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

### 0. Setup worktree
- Get the task: `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
- Extract `metadata.project` and `metadata.branch`.
- Skip worktree setup for `type: init` tasks (project may not exist yet).
- Create a worktree for this task:
  ```
  cd /workspace/<project>
  git worktree add /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} <branch>
  ```
- All subsequent git operations happen in `/workspace/<project>-{{ env.HERMES_KANBAN_TASK }}`.
- If worktree already exists (resume):
  - Check if it's usable: `cd /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} && git status`
  - If `git status` fails or worktree is locked → prune and recreate:
    ```
    cd /workspace/<project>
    git worktree prune
    git worktree remove --force /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} 2>/dev/null || true
    git worktree add /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} <branch>
    ```
  - Otherwise → use the existing worktree (resume).

## Dispatch

1. **Fetch the task**
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract `title`, `description`, and `metadata`.
   - Required metadata: `project`. If missing, block with reason.
   - `branch` / `repo_url` are required only for the relevant flow (see step 2).

2. **Determine task type** from `metadata`:
   - `type == "init"` → load `skill_view("execute-task", "references/init.md")` and follow it. Project rules are not loaded — the project may not exist yet.
   - `component == true` → load `skill_view("execute-task", "references/memory.md")` and run its load procedure, then load `skill_view("execute-task", "references/rag.md")` and run its recall procedure, then load `skill_view("execute-task", "references/component.md")` and follow it.
   - `pr_creation == true` → load `skill_view("execute-task", "references/memory.md")` and run its load procedure, then load `skill_view("execute-task", "references/pr.md")` and follow it.
   - `type == "review"` → load `skill_view("execute-task", "references/memory.md")` and run its load procedure, then load `skill_view("execute-task", "references/rag.md")` and run its recall procedure, then load `skill_view("execute-task", "references/review-fix.md")` and follow it. This flow is entered when QA moved the task back for fixes; `project`, `branch`, and `pr_url` come from task metadata.
   - Otherwise → `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "Unknown task type"`.

## Conventions (all flows)

- Call `kanban_heartbeat` before each `skill_run` and before long-running operations (validation).
- On failure of any step: capture the error and `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`.
- On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] <summary> | steps=<N> | retries=<N>"` — see the loaded flow for the exact comment. Track the number of skill_run calls (steps) and retry attempts for metrics.
- The workspace is at `/workspace/<project>-<task_id>` (worktree); the shared repo is at `/workspace/<project>`.
- Start the coder agent with `--skip_context_files` to avoid overloading the global memory.
- Experience memory (E-pool via dense-mem, see `references/rag.md`): recall before executing, remember after success. Memory tools are exposed as `mcp_dense_mem_*`; a failed memory call must never block the task.

## Quality Targets (judge rubric dimensions)

QA will score your PR on a 1–10 rubric. Code scoring ≥ 7 is saved as a verified template;
code scoring ≤ 4 is retracted from memory as an anti-pattern.

| Dimension | Weight | Target |
|-----------|--------|--------|
| Code quality | 25% | DRY, clear naming, separation of concerns, no dead code |
| Tests | 25% | Cover new logic, test edge cases, meaningful assertions |
| Security | 25% | No hardcoded secrets, input validation, auth checks |
| Docs & conventions | 25% | Follow AGENTS.md, JSDoc where needed, no TODO-blockers |

Before committing, verify your code against these dimensions. If any is clearly deficient — fix it before pushing.

## Content Quality Overlay (when `type == content`)

For content tasks (`type == content`, or components that produce `artifacts/*.md` files), load `references/prose-quality.md` and apply it AFTER the standard quality check. This is an additional layer — it does not replace the rubric above.

1. **Banned word scan** — grep the output for every word in the "Banned Lexical Tells" and "Banned Phrases" lists. Replace any found before committing.
2. **Specificity check** — every benefit claim must have a number, percentage, or named example. Abstract claims ("save time", "improve efficiency") → rewrite with concrete data.
3. **Voice check** — read 3 sentences aloud. If they sound like a generic LinkedIn post → rewrite with tighter POV and varied rhythm.
4. **CTA check** — if a CTA exists, it must describe the actual next step ("See a 2-min demo", "Book a call", "View pricing"). Generic CTAs ("Get Started", "Learn More") → rewrite.
5. **Copy-paste test** — could this text appear unchanged on a competitor's site? If yes → add project-specific specifics.

If any of these checks fail, fix the content before pushing. QA will re-check against `prose-quality.md` scoring guide.
