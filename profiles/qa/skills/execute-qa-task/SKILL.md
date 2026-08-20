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
- Create a worktree for this task:
  ```
  cd /workspace/<project>
  git worktree add /workspace/<project>-{{ env.HERMES_KANBAN_TASK }} <branch>
  ```
- All subsequent git operations happen in `/workspace/<project>-{{ env.HERMES_KANBAN_TASK }}`.
- If worktree already exists (resume), just use it.
- Skip worktree setup for `type: deploy` tasks (FTP deploy uses remote operations only).

### 1. Fetch the task
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract `title`, `description`, `metadata`.
   - Ensure the task is in `ready` state.

2. **Dispatch by task type**
   - **`metadata.type == "release"`** → run the release flow:
     - Required metadata: `project`. If missing, block with reason.
     - Call `skill_discover("release-to-main")`; if found, call `skill_run(release-to-main, project)`.
     - The `release-to-main` skill handles: PR creation (dev → main), HITL block, and merge after unblock.
     - **Return here** — do not run the review or deploy flows.
   - **`metadata.type == "deploy"`** → run the FTP deploy flow:
     - Required metadata: `project`. If missing, block with reason.
     - Call `skill_discover("deploy-ftp")`; if found, call `skill_run(deploy-ftp, project)`.
     - The `deploy-ftp` skill downloads the latest release zip from GitHub Releases and uploads it to the server via FTP. No HITL gate — it's a mechanical operation.
      - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] FTP deploy completed for {{ project }}. | steps=<N> | retries=<N>"`
     - On failure: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "FTP deploy failed: <error details>"`
     - **Return here** — do not run the review flow.
   - **Otherwise (default, `type == "review"`)** → continue with the review pipeline below.

## Review Pipeline

3. **Load project rules from the RAG cache (E-pool)**
   - Extract from `metadata`:
     - `rules_keys` – list of rule keys needed (`["testing-patterns", "review-standards", ..]`)
     - `rules_hash` – version stamp from orchestrator
   - For each key in `rules_keys`:
     - Recall the rule record: `mcp_dense_mem_recall_memory(query="project rules for <project>: <key>", filter={tags: ["project-rules:<project>", "rules:<key>"]} where the tool supports filters)`.
     - If found AND its `rules_hash` claim equals `rules_hash` → use it.
     - If not found OR mismatch → read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` and extract the relevant section directly (deterministic fallback).
     - Do **not** write rule records from the QA profile (rules are owned by the orchestrator).
   - If `rules_keys` is empty → load essential QA guidelines from `AGENTS.md` or fallback to generic.

4. **Pre-merge acceptance criteria check** (BEFORE review-and-merge)
   - If `metadata.acceptance_criteria` exists and is non-empty:
     - For each criterion, verify against the PR diff and codebase:
       - **Automated criterion** (mentions "lint", "test", "build", "passes", "no errors") → run the matching validation command from `AGENTS.md`. If it fails → append failure to summary, skip to step 5 as NEEDS_FIXES without merging.
       - **Manual criterion** (mentions "matches design", "responsive", "accessible") → note as "pending manual verification" — proceed with review but flag these for post-merge verification.
     - If any automated criterion fails → **do NOT call review-and-merge**. Block or bounce to coder immediately with the specific failure.
   - If `metadata.acceptance_criteria` is missing → proceed with review (legacy tasks without criteria).

5. **Run the QA pipeline**
   - **Step 5.1**: Call `skill_discover("review-and-merge")` to find the appropriate skill.
   - If found: call `skill_run(review-and-merge, project, branch, pr_url, rules_context)`.
   - If not found: fallback to a generic QA skill (or block with "Missing QA skill").
   - **Step 5.2 (optional, best-effort)**: call `mcp_dense_mem_recall_memory(query="<review focus, e.g. known pitfalls for <project> or the component type>")` and consider past failure patterns during the review. On failure or empty results, continue without it.
   - The `review-and-merge` skill should:
     - Run automated tests (linting, unit, integration).
     - Perform code review (static analysis, security checks, adherence to guidelines).
     - Merge the PR to `dev` and deploy to Vercel staging.
     - Return a report with status (success / failure / needs-fixes).
   - **Step 5.3 (judge, after review-and-merge returns SUCCESS)**:
     - Call `skill_discover("pr-judge")`. If found, call `skill_run(pr-judge, pr_url, branch, project, rules_context)`.
     - The judge returns `[judge_score=N] summary | quality=N tests=N security=N docs=N`.
     - Parse the score. If pr-judge is not found, skip scoring (treat as neutral).

6. **Handle the result**
   - **Post-merge manual criteria check** (for criteria flagged as "pending manual verification" in step 4):
     - If any manual criterion (e.g. "matches design", "responsive") is clearly not met → log it but do not block (these were already flagged pre-merge).
   - **If `review-and-merge` returns SUCCESS**:
     - Include judge score in the completion comment if available:
         `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] QA passed. Merged to dev and deployed to Vercel staging. | steps=<N> | retries=<N> | judge_score=N"`
     - **Memory decision based on judge score** (best-effort, fire-and-forget):
       - **Score ≥ 7 (verified)**: `mcp_dense_mem_remember(evidence="<what was done, key decisions, what made it high quality>", tags=["verified", "judge:<score>", "project:<project>"], confidence=high)`.
       - **Score 5–6 (neutral)**: Do not store. No memory action.
       - **Score ≤ 4 (anti-pattern)**: Retract any positive QA-owned evidence about this pattern with `mcp_dense_mem_retract_evidence(...)`, then store: `mcp_dense_mem_remember(evidence="anti-pattern: <what went wrong, root cause, what to avoid>", tags=["anti-pattern", "judge:<score>", "project:<project>"], confidence=high)`.
       - On memory call failure, continue without blocking.
    - **If `review-and-merge` returns NEEDS_FIXES** (minor issues, comments):
        - **Iteration tracking**: Read `metadata.review_iterations` (default 0). Increment by 1: `new_iterations = review_iterations + 1`.
        - **Exploration count**: Read `metadata.exploration_count` (default 0). This counter persists across re-decompositions (inherited from parent → children).
        - **Hard limit — MAX_EXPLORATIONS = 2** (i.e. 2 re-decomposition rounds = minimum 6 total review iterations):
          - If `exploration_count >= 2`: the task has been re-decomposed twice and still fails. **Terminal state.**
            - `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "MAX_EXPLORATIONS_REACHED: Task failed after <exploration_count> exploration rounds (<new_iterations> total review iterations). Requires manual intervention — use /cancel or re-scope the task."`
            - Store final anti-pattern (best-effort): `mcp_dense_mem_remember(evidence="TERMINAL: Task '<title>' (project <project>) exhausted <exploration_count> exploration rounds. Total iterations: <new_iterations>. Manual intervention required — the task scope or approach needs fundamental redesign.", tags=["anti-pattern", "terminal", "project:<project>"], confidence=high)`
            - **Return here** — do not bounce to coder or orchestrator.
        - **Exploration escalation** (if iteration ≥ 3 AND `exploration_count < 2`):
         - The coder-QA loop has bounced 3+ times. This signals a systemic issue, not a simple fix.
         - **Store anti-pattern** (best-effort, never block):
           ```
           mcp_dense_mem_remember(
             evidence="EXPLORATION: Task '<title>' (project <project>) failed <new_iterations> review iterations. Approach tried: <describe the approach from task description>. QA findings across iterations: <summary of recurring issues>. This decomposition strategy did not work — orchestrator must try a different approach.",
             tags=["anti-pattern", "exploration", "project:<project>", "type:<task_type>"],
             claims=["exploration:true", "iterations:<new_iterations>"],
             confidence=high
           )
           ```
           On memory failure, continue without blocking.
         - Move the task back to the **orchestrator** (not coder) for re-decomposition:
           ```
           kanban_move --task {{ env.HERMES_KANBAN_TASK }} --status ready --assignee orchestrator \
             --comment "EXPLORATION TRIGGERED: Task has been through <new_iterations> review iterations without passing. Previous approach is not working. Re-decompose with a different strategy: try simpler components, different tech choices, or break into smaller pieces. Original QA findings: <summary>"
           ```
          - Update metadata: `kanban_update(task_id, metadata: { review_iterations: <new_iterations>, exploration_triggered: true, exploration_count: <exploration_count + 1>, priority_score: <current_score + 5> })`.
         - The high priority_score ensures the orchestrator picks this task next.
         - **Return here** — do not bounce to coder again.
       - **Normal bounce** (iteration < 3):
         - Move the task back to the coder as **high priority** so the coder loop picks it up next:
         - `kanban_move --task {{ env.HERMES_KANBAN_TASK }} --status ready --assignee coder --comment "QA found issues (iteration <new_iterations>): <summary>"` and keep `metadata.type == "review"` (so the coder's `execute-task` routes it to the fix flow) plus `metadata.priority = "high"`, `metadata.review_iterations = <new_iterations>`, `metadata.priority_score = <current_score + 1>`.
         - If a wrong pattern was likely replayed from the E-pool, say so in the comment so the coder can trace and retire its own evidence during the fix loop (see `execute-task` reference `rag.md`). You can only correct/retract evidence your own QA profile submitted; coder-owned evidence is fixed by the coder.
   - **If `review-and-merge` returns FAILURE** (critical errors, deployment failure, CI crash):
     - `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "QA failed: <error details>"`.

7. **Heartbeat and error handling**
   - Call `kanban_heartbeat` before each long-running operation (especially before `review-and-merge` or `deploy-ftp`).
   - If any `skill_run` fails, capture the error and call `kanban_block` with details.
   - Do not poll or loop — this skill runs once per task.

## Important Notes
- Workspace is at `/workspace/<project>-<task_id>` (worktree); the shared repo is at `/workspace/<project>`.
- For review tasks the `pr_url` should be present in metadata. If missing, block with "No PR URL provided".
- Release tasks (`type: release`) only need `project` — they create a PR from dev to main, block for HITL approval, then build and create a GitHub Release with zip artifact.
- Deploy tasks (`type: deploy`) only need `project` — they download the latest release zip from GitHub and upload it to the server via FTP. No HITL gate — the deploy is a mechanical operation.
- The review pipeline skills are expected to return a structured result — you may need to standardize its output format (e.g., a JSON with `status`, `message`, `details`).
- If the task has no `rules_keys`, you can still run a generic QA, but it's highly recommended to include them for context-aware reviews.

## Rules cache (project rules via RAG E-pool, same as `execute-task` → `references/memory.md`)
- Rules are stored by the orchestrator (dispatcher profile) in dense-mem, tagged `project-rules:<project>` (+ `rules:<key>` per rule, `rules-index` for the index record).
- `rules_hash` in task metadata invalidates the cache; disk `AGENTS.md` / `SOUL.md` is the deterministic fallback.
- Tagged rules records are authoritative over untagged experience records.

## Experience memory (E-pool via dense-mem)
- Tools are exposed as `mcp_dense_mem_*` (server `dense_mem` in `config.yaml`).
- Tagged rules records (`project-rules:<project>`) are authoritative; untagged experience records are advisory only.
- All memory calls are best-effort: on failure, continue the task without memory.
- Ownership: dense-mem lets a profile correct/retract only its own submitted evidence.
