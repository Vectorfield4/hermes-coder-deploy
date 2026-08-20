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
- Skip worktree setup for `type: init` tasks.
- Create or reuse worktree:
  ```
  cd /workspace/<project>
  git worktree add /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} <branch>
  ```
- If worktree exists (resume): check `git status`. If fails or locked → prune and recreate. Otherwise → use existing.

### 1. Dispatch by task type
- `type == "init"` → load `references/init.md`. No project rules.
- `component == true` → load `references/memory.md` (rules) → `references/rag.md` (recall) → `references/component.md`.
- `pr_creation == true` → load `references/memory.md` → `references/pr.md`.
- `type == "review"` → load `references/memory.md` → `references/rag.md` → `references/review-fix.md`.
- Otherwise → `kanban_block --reason "Unknown task type"`.

## Conventions

- `kanban_heartbeat` before each `skill_run` and long operations.
- Failure → `kanban_block --reason "<error>"`.
- Success → `kanban_complete --comment "[outcome=success] <summary> | steps=<N> | retries=<N>"`.
- Workspace: `/workspace/<project>-<task_id>` (worktree). Shared: `/workspace/<project>`.
- Start coder with `--skip_context_files`. Memory (E-pool): recall before, remember after. Failed memory calls never block.

## Quality Targets (judge rubric)

Score ≥ 7 → verified template. Score ≤ 4 → retracted as anti-pattern.

| Dimension | Weight | Target |
|-----------|--------|--------|
| Code quality | 25% | DRY, clear naming, separation of concerns |
| Tests | 25% | Cover new logic, edge cases, meaningful assertions |
| Security | 25% | No hardcoded secrets, input validation, auth checks |
| Docs & conventions | 25% | Follow AGENTS.md, JSDoc where needed |

Verify before committing. Fix deficient dimensions.

## Content Quality Overlay (`type == content`)

Load `references/prose-quality.md`. Apply AFTER standard quality check:
1. Grep for banned words/phrases. Replace any found.
2. Every benefit claim must have a number/constraint. Abstract → rewrite.
3. CTA must describe the actual next step. Generic → rewrite.
4. Copy-paste test: could it appear on a competitor's site? If yes → add specifics.

## Verification
- Worktree exists at `/workspace/<project>-<task_id>` and is on the correct branch.
- Task status is one of: `done` (component or PR created), `blocked` (error), or `ready` (bounced back from QA).
- No task remains in an intermediate state after this skill completes.
- For `type: content` tasks: grep for banned words returns zero matches against `prose-quality.md`.
