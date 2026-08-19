---
name: orchestrate-task
description: Breaks down complex development tasks into parallel sub-tasks for coder agents, coordinating a single feature branch and final PR creation.
metadata:
  hermes:
    tags: [orchestrator, dispatcher, planning]
    related_skills: [project-discover]
---

# Orchestrate Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

### 1. Fetch the Task
- Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
- Extract `title`, `description`, and `metadata`.

### 2. Determine Project Context
- If `metadata.project` is set AND `metadata.project` is not "default":
  - Use it. Navigate to `/workspace/<project>`.
- If `metadata.project` is "default" or not set:
  1. Recall from E-pool: `mcp_dense_mem_recall_memory(query="default project", filter={tags: ["system:projects"]})`. If found → set project = recalled name.
  2. Else: list `/workspace/` directories. If exactly one → set project = that directory name.
  3. If multiple → use LLM: "Which of these projects matches this task? Projects: <list dirs> | Task: <description>".
  4. If workspace is empty → project = "default", add comment: "No project found in workspace. Create one with /project add."
- Navigate to `/workspace/<project>`. If the directory does not exist → block task: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "Project <project> not found in workspace"`.

### 3. Load and index project rules (once per project per git hash, cached in the RAG E-pool)
- Navigate to `/workspace/<project>`.
- Pull latest changes: `git pull origin dev` (or `main` if `dev` does not exist).
- Get current git commit hash: `git rev-parse HEAD` → `rules_hash`.
- Recall the rules index from the E-pool: `mcp_dense_mem_recall_memory(query="project rules for <project> (index)", filter={tags: ["project-rules:<project>", "rules-index"]} where the tool supports filters)`.
- If the recalled index record exists AND its `rules_hash` claim matches the current `rules_hash` → use the cached rules.
- Otherwise (missing or stale):
  - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` (if exist).
  - Use LLM to extract key rule sections (e.g., `ui-conventions`, `api-standards`, `testing-patterns`).
  - Store each section in the E-pool (best-effort): `mcp_dense_mem_remember(evidence=<section>, tags=["project-rules:<project>", "rules:<key>"], claims=[<rules_hash claim>], confidence=high)`.
  - Store the index record: `mcp_dense_mem_remember(evidence={"keys": [...], "rules_hash": "<rules_hash>"}, tags=["project-rules:<project>", "rules-index"], confidence=high)`.
  - If a stale index/rule record was recalled, retire it best-effort via `mcp_dense_mem_retract_evidence(...)` (the dispatcher owns these records).
  - Note: `remember` is asynchronous — freshly stored records become recallable after the verifier settles; the rules extracted from disk are already in this run's context, so planning does not depend on it.
- Graceful degradation: if any MCP call fails, extract the rules directly from disk and carry them in the decomposition context — planning must never block on the E-pool.
- Regardless of cache status, always pass the current `rules_hash` and `rules_keys_needed` to sub-tasks.

### 4. Recall related past experience (RAG E-pool)
- Call `mcp_dense_mem_recall_memory(query="<short goal summary of the task>")` to find similar past plans, decisions, or patterns for this project.
- **Recall anti-patterns** for this project: `mcp_dense_mem_recall_memory(query="<goal>", filter={tags: ["anti-pattern", "project:<project>"]})`. If recalled, these are known failures — use a different decomposition approach.
- Include the returned evidence contexts in the decomposition prompt as **advisory experience hints only** — project rules (step 3) always take precedence.
- Graceful degradation: if the MCP call fails or returns no results, continue without it. Planning must never block on the memory layer.
- Project rules (step 3) always take precedence over anything recalled from the E-pool.

### 5. Decompose the task

#### 5a. Domain classification
Classify the task into a domain BEFORE decomposing:
- **Page/landing** → narrative arc required, marketing blocks, scroll animations, 3D elements possible
- **Dashboard/app** → data flow, state management, forms, tables
- **Component** → atomic design level, reusability, storybook
- **Content** → copywriting, SEO, accessibility
- **API/backend** → endpoints, data models, error handling

For pages/landings: FIRST define the narrative arc (pain → solution → transformation → result), THEN map each act to architectural components.

#### 5b. Architectural decomposition
The orchestrator describes components using architectural language and tags. The coder discovers the right skill via tag matching.
1. **Atomic level** — atom / molecule / organism / template / page
2. **Functional purpose** — what this component DOES (hero, feature-grid, lead-form, case-study)
3. **Behavioral requirements** — how it ACTS (scroll-triggered, animated, responsive, lazy-loaded, 3D-interactive)
4. **Domain context** — what business goal it serves (trust-building, conversion, education)

**Page/landing template (narrative-driven):**

| # | Component | Atomic Level | Purpose | Behavior |
|---|-----------|-------------|---------|----------|
| 1 | Narrative architecture | — | Story arc, USP, audience, pain points | Output: artifacts/narrative.md |
| 2 | Content plan | — | Copy per narrative act, headlines, CTAs | Output: artifacts/content-plan.md |
| 3 | Page template | template | Section ordering, responsive grid, spacing | Layout skeleton |
| 4 | Hero organism | organism | Primary value proposition, main visual | scroll-fade-in, 3D scene anchor |
| 5 | Feature organisms | organism(s) | Technology/solution blocks | scroll-stagger, icon animations |
| 6 | 3D/interactive scene | organism | Data viz, demo, or visual metaphor | scroll-synced, lazy-loaded |
| 7 | Social proof organism | organism | Testimonials, cases, metrics | counter animations |
| 8 | Lead capture molecule | molecule | Form with validation | appears at emotional peak |
| 9 | Animation orchestration | — | GSAP timeline, scene-UI sync | scroll-triggered choreography |
| 10 | Performance layer | — | Code splitting, lazy loading, memoization | Core Web Vitals targets |

**Dashboard/app template:**

| # | Component | Atomic Level | Purpose |
|---|-----------|-------------|---------|
| 1 | State architecture | — | Zustand stores, data model |
| 2 | Page template | template | Routes, layout, navigation |
| 3 | Data organisms | organism | Tables, charts, data views |
| 4 | Form molecules | molecule | Input, validation, submission |
| 5 | API integration | — | TanStack Query hooks, error handling |

Adjust the template based on the actual task. Not every component is needed — include only what the task requires.

#### 5c. Component description template
For each component, produce a description using this structure:

```
## <Component Title>

**Atomic level:** atom | molecule | organism | template | page
**Purpose:** <what this component achieves in the page architecture>
**Behavior:**
- <how it interacts with user/scroll/state>
- <animation requirements if any>
- <responsive breakpoints>
```

For each component, also produce:
- `tags` — architectural tags for skill discovery by the coder. Include: atomic level, domain, behavior, and purpose keywords. Example: `["organism", "hero", "animation", "scroll", "3d-scene", "b2b", "landing"]`. More tags = better skill match.
- `type` — broad type for categorization: `ui` / `3d` / `content` / `integration`
- `rules_keys_needed` — subset of rules from the index relevant to this component
- `acceptance_criteria` — 2-5 concrete, testable conditions (see 5d)

#### 5d. Acceptance criteria enrichment
Each component's acceptance criteria MUST include where applicable:
1. **Functional** — what the component does (e.g. "Renders hero section with title, subtitle, and CTA button")
2. **Visual** — responsive behavior, breakpoints (e.g. "Mobile: stacks vertically, Desktop: 2-column grid")
3. **Animation** — specific motions (e.g. "Hero text fades in on scroll, 3D scene starts rotating at 30% viewport")
4. **Narrative** — story coherence for content blocks (e.g. "Copy follows the pain→solution→result arc from artifacts/narrative.md")
5. **Technical** — lint/test/build passes (e.g. "npm run lint passes, no TypeScript errors")

#### 5e. Self-check before creating sub-tasks
For each component, verify:
1. Every criterion traces to the original task `description` — not invented.
2. At least one criterion is verifiable via lint/test/build (from project `AGENTS.md`).
3. The atomic level is semantically correct (a full section is an "organism", not an "atom").
4. Behavioral requirements are specific enough to implement (not "looks good" but "fades in on scroll at 30% viewport").
5. Tags are rich enough for the coder to discover the right skill (at least 3 tags per component).

If a criterion fails these checks, rewrite or drop it. Bad criteria propagate to QA and waste review cycles.

#### 5f. Exploration re-decomposition
If `metadata.exploration_triggered == true` (task bounced back after >=3 failed review iterations):
1. **Recall exploration anti-patterns** (best-effort):
   ```
   mcp_dense_mem_recall_memory(
     query="exploration anti-pattern for <project>: <task title>",
     filter={tags: ["anti-pattern", "exploration", "project:<project>"]}
   )
   ```
   These records describe *what approach was tried and why it failed*. Treat them as **authoritative avoidance constraints** — use a provably different decomposition strategy.
   On failure or empty results, continue without them.
2. Read the previous component structure (from the task's child links or comments).
3. Analyze what went wrong using QA findings + recalled anti-patterns.
4. Re-decompose with a **different strategy**: fewer components, simpler scope, different tech choices, or a completely different approach. **The new decomposition must be provably different from the anti-patterns recalled.**
5. Add a comment: `[exploration] Re-decomposed with alternative strategy: <what changed and why>. Anti-patterns avoided: <summary of recalled anti-patterns>`.
6. Preserve the original `project`, `branch`, and `rules_hash` — the new components continue on the same branch.

### 6. Generate a Unique Feature Branch Name
- Create `feature/<task_id>-<sanitized_title>` (e.g., `feature/42-login-page`).  
- This branch will be used by all sub-tasks.

### 7. Create Sub-Tasks for Each Component
- For each component, call:
kanban_create(
title: "<title>",
description: "<description>",
assignee: coder,
status: ready,
metadata: {
project: "<project>",
branch: "<branch_name>",
type: "<component_type>",
parent_id: "{{ env.HERMES_KANBAN_TASK }}",
component: true,
rules_hash: "<rules_hash>",
rules_keys_needed: ["<key1>", "<key2>"],
acceptance_criteria: ["<criterion 1>", "<criterion 2>"],
tags: ["<atomic_level>", "<purpose>", "<behavior1>", "<behavior2>", "<domain>"],
exploration_count: <parent's exploration_count or 0>
}
)
- Store the returned IDs.
- The `tags` field is used by the coder for skill discovery. It MUST include the atomic level (atom/molecule/organism/template/page), functional purpose (hero/feature-grid/lead-form/etc.), behavioral keywords (animation/scroll/3d-scene/form/etc.), and domain context (b2b/marketing/landing/etc.). More tags = better skill matching.

### 8. Create the Final PR Task
- This task will combine all changes and create a pull request.
- Call:
kanban_create(
title: "PR: <branch_name>",
description: "Aggregate changes from all components, validate, commit, push, and open PR.",
assignee: coder,
status: blocked,
metadata: {
project: "<project>",
branch: "<branch_name>",
parent_id: "{{ env.HERMES_KANBAN_TASK }}",
pr_creation: true,
rules_hash: "<rules_hash>",
rules_keys_needed: ["validation-commands", "code-review-guidelines"],
exploration_count: <parent's exploration_count or 0>
}
)
- Store its ID.

### 9. Link All Tasks as Children of the Parent
- For each sub-task ID (components + PR task), call:
kanban_link --parent {{ env.HERMES_KANBAN_TASK }} --child <subtask_id>

### 10. Set dependencies for the PR task
- The PR task must wait for all component tasks to finish.
- For each component task ID, call: kanban_link --parent <pr_task_id> --child <component_id> --block
- This ensures the PR task becomes `ready` only after all components are `done`.

### 11. Complete orchestration
- Close the parent task: kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "[outcome=success] Orchestration complete. Decomposed into N components + 1 PR task. | steps=<N> | retries=<N>"

### 12. Error handling
- If any `kanban_create` or `kanban_link` call fails, capture the error and call: kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error message>"
- Do not poll or loop – this skill runs once per task.