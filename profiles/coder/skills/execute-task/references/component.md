# Component Execution (`component == true`)

Loaded by `execute-task` after the project rules have been loaded (see `references/memory.md`).

## Steps

0. **Validate acceptance criteria** (before doing any work)
   - Read `metadata.acceptance_criteria` if present.
   - For each criterion:
      - Does it trace to the original task `description`? If it is invented or unrelated → drop it from your checklist and proceed.
     - Is it verifiable via the project's validation commands (lint/test/build)? If not → note it as "manual review only" so you know QA will eyeball it.
   - If `acceptance_criteria` is missing entirely → proceed but add a comment: `"No acceptance_criteria in metadata — QA will review against description only"`.
   - This prevents executing against wrong criteria and wastes fewer review cycles.

1. **Identify component type**
   - Use `metadata.type` if present (ui, content, integration, 3d).
   - Else, infer from `title`/`description`.

2. **Recall related experience (RAG E-pool)**
   - If `references/rag.md` is not loaded yet, load it via `skill_view("execute-task", "references/rag.md")`.
   - Follow its recall procedure: call `mcp_dense_mem_recall_memory(query="<concise goal of this component>")`.
   - Pass relevant recalled patterns/decisions into the skill call as advisory context.
   - Graceful degradation: on MCP failure or empty results, continue without recalled context.

3. **Fetch latest and rebase** (parallel-safe git flow)
   - Navigate to the worktree: `cd /workspace/<project>-{{ env.HERMES_KANBAN_TASK }}`.
   - Fetch the latest changes from origin:
     ```
     git fetch origin <branch>
     ```
   - Rebase on the latest state of the branch:
     ```
     git rebase origin/<branch>
     ```
   - If rebase conflict: resolve it (see `resolve-merge-conflict` skill — you are already in the worktree on the correct branch, so skip the "Switch to the PR branch" step) or abort and report.
   - This ensures the coder works on top of any changes pushed by other parallel coders.

4. **Discover and invoke the right skill**
   - The orchestrator describes components using architectural language and tags, NOT skill names. You discover the right skill by tag matching.
   - **Collect tags** from:
     - `metadata.tags` — architectural tags set by the orchestrator (atomic level, purpose, behavior, domain)
     - `metadata.type` — broad type (ui / 3d / content / integration)
     - Keywords from the component's `title` and `description` that match architectural concepts
   - **Discover:** call `skill_discover(tags)` with the combined tag set. The system returns skills ranked by tag overlap. Pick the skill with the highest match.
   - **Load stack references** based on the discovered skill:
     - UI/layout → `references/mui.md`, `references/react.md`
     - 3D → `references/threejs-r3f.md`
     - Animation → `references/gsap.md`
     - State/forms → `references/zustand.md`, `references/react-hook-form.md`, `references/zod.md`
     - Data → `references/tanstack-query.md`
   - **Invoke:** `skill_run(<discovered_skill>, project, branch, description, rules_context)`.
   - Then call `kanban_heartbeat`.
   - **Fallback:** if no skill matches or `skill_discover` returns empty → `skill_run(simple-task-executor, project, branch, description)` as catch-all.
   - Each skill should write changes to the worktree directory.

5. **Quality check and commit**
   - Before committing, verify against the judge rubric (see `execute-task` → Quality Targets):
     - Code quality: clean, DRY, well-named?
     - Tests: new logic covered?
     - Security: no secrets, input validated?
     - Docs: conventions followed?
   - If any dimension is clearly deficient → fix before committing.
   - Add all changes: `git add .`
   - Commit: `git commit -m "Task #<task_id>: <description>"`
   - Push: `git push origin <branch>`
   - If push fails due to conflict (another coder pushed first): fetch → rebase → push again.
   - Load retry protocol for push: `skill_view("create-pr", "references/retry.md")`.

6. **Complete the component task**
   - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "Component implemented."`
     - Then store the outcome as experience (best-effort): follow the `remember` procedure in `references/rag.md` — a concise summary of what was implemented and the key decisions. Do not block task completion on memory writes.
   - On failure: 
     - `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`
     - Clean up worktree (best-effort, never block on cleanup):
       ```
       cd /workspace/<project> && git worktree remove --force /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} 2>/dev/null || true
       ```
