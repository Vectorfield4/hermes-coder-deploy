# Component Execution (`component == true`)

Loaded by `execute-task` after the project rules have been loaded (see `references/memory.md`).

## Steps

1. **Identify component type**
   - Use `metadata.type` if present (ui, content, integration).
   - Else, infer from `title`/`description`.

2. **Invoke the right skill**
   - Route by the explicit type → skill map below. The map is **authoritative**: `skill_discover(type)` alone is ambiguous because several skills share the `ui` / `content` tags (e.g. `ui` matches `ui-implementer`, `ui-architect`, `simple-task-executor`, `threejs-scene-builder`).
   - Type-to-skill mapping (standardized stack, see project `AGENTS.md`):
     - `ui` → `ui-implementer` (or `simple-task-executor` for quick forms/tables)
     - `3d`/`threejs` → `threejs-scene-builder`
     - `integration` → `integration-specialist`
     - `content` → `content-strategist` / `narrative-designer`
     - planning → `technical-planner`
   - Call `skill_run(<mapped_skill>, project, branch, description, rules_context)`.
   - Fallback: if the mapped skill is not installed, call `skill_discover(type)`; if still nothing is found, `skill_run(simple-task-executor, project, branch, description)`.
   - Before each `skill_run`, load the matching `frontend-stack` reference via `skill_view("frontend-stack", "references/<file>.md")`:
     - ui → `references/mui.md`, `references/react.md` (plus `zustand.md` / `tanstack-query.md` when state/data is involved)
     - 3d / threejs → `references/threejs-r3f.md`
     - integration → `references/react-router.md`, `references/tanstack-query.md`, `references/zustand.md`, `references/msw.md`
     - content → `references/react.md`, `references/mui.md`
     - any test work → `references/vitest.md`, `references/msw.md`
   - Then call `kanban_heartbeat`.
   - Each skill should write changes to `/workspace/<project>` on the given `branch`.

3. **Complete the component task**
   - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "Component implemented."`
   - On failure: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`
