---
name: execute-task
description: Executes a single development sub-task (UI, content, integration) or aggregates changes and creates a PR.
metadata:
  hermes:
    tags: [coder, executor]
---

# Execute Task

## Input
- Task ID from `{{ env.HERMES_KANBAN_TASK }}`.

## Steps

1. **Fetch the task**
   - Call `kanban_get_task({{ env.HERMES_KANBAN_TASK }})`.
   - Extract `title`, `description`, and `metadata`.
   - Required metadata: `project`, `branch`. If missing, block with reason.

2. **Load project rules from memory (cached)**
   - For each key in `rules_keys_needed`:
     - Try to read `memory_read(project_{project}_rules_{key})`.
     - If found AND stored metadata.hash == `rules_hash` → use it.
     - If not found OR hash mismatch:
       - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` (if exist).
       - Extract the specific rule section for this key.
       - Call `memory_replace(project_{project}_rules_{key}, <extracted_rule>, metadata: {hash: <rules_hash>})`.
       - Use the rule in current task context.
   - If any rule is missing and cannot be extracted → `kanban_block` with reason.

3. **Determine task type**
   - Inspect `metadata`:
     - If `component == true` → go to **Component Execution**.
     - If `pr_creation == true` → go to **PR Creation**.
     - Otherwise, block with "Unknown task type".

---

### Component Execution (`component == true`)

4. **Identify component type**
   - Use `metadata.type` if present (ui, content, integration).
   - Else, infer from `title`/`description`.

5. **Discover and invoke the right skill**
   - Call `skill_discover(type)` to find a skill with matching tag.
   - Example: `skill_discover("ui")` → returns the best matching skill name.
   - If found: call `skill_run(<discovered_skill>, project, branch, description, rules_context)`.
   - If not found: fallback to `skill_run(generic-developer, project, branch, description)`.
   - Before each `skill_run`, call `kanban_heartbeat`.
   - Each skill should write changes to `/workspace/<project>` on the given `branch`.

6. **Complete the component task**
   - On success: kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "Component implemented."
   - On failure: kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"

### PR Creation (`pr_creation == true`)

7. **Ensure all components are done**
   - Since this task is `blocked` until all components are done, it becomes `ready` automatically.
   - Verify that the branch contains changes.

8. **Review the changes (two-stage review)**
   - Call `skill_run(code-review, project, branch, rules_context)`.
   - If review fails → `kanban_block` with issues.
   - If review passes → proceed to validation.

9. **Validate the code**
   - Run project-specific validation (linting, tests).
   - Use validation commands from cached rules (step 2) or from `AGENTS.md`.
   - Call `kanban_heartbeat` before validation.

10. **Create the pull request**
    - Call `skill_run(create-pr, project, branch)`.
    - This skill commits all changes, pushes the branch, and opens a PR.

11. **Finalize the PR task**
    - On success: `kanban_complete --task {{ env.HERMES_KANBAN_TASK }} --comment "PR #<number> created."`
    - On failure: `kanban_block --task {{ env.HERMES_KANBAN_TASK }} --reason "<error>"`

## Error Handling
- If any `skill_run` fails, capture the error and call `kanban_block`.
- If the task type is unknown, block with explanation.
- Use `kanban_heartbeat` before long-running operations (validation, code-review).

## Memory Schema (per project)
**Index entry** (created by orchestrator):
memory_replace(project_{project}_rules_index, {
keys: ["ui-conventions", "api-standards", "testing-patterns"],
hash: "a1b2c3d4...",
updated_at: "2026-08-13T10:00:00Z"
})

**Rule entry** (created by coder on demand, or by orchestrator if proactive):
memory_replace(project_{project}_rules_ui-conventions, "content...", metadata: {hash: "a1b2c3d4..."})

**Cache invalidation logic** (in coder step 2):
```python
if stored_hash != metadata.rules_hash:
    # reload from disk and update memory
    memory_replace(...)
```

## Notes
- This skill assumes the workspace is available at /workspace/<project>.
- The branch is shared across all component tasks.
- PR creation is delegated to the dedicated create-pr skill.
- To avoid overloading the global memory, use --skip_context_files when starting the coder agent.
