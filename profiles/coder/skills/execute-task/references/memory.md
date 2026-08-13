# Project Rules Memory (per project)

Loaded by `execute-task` before component / PR flows. Rules are cached in agent memory and keyed by the project rules hash.

## Load procedure (for component / PR tasks)

For each key in `rules_keys_needed`:
- Try to read `memory_read(project_{project}_rules_{key})`.
- If found AND stored metadata.hash == `rules_hash` → use it.
- If not found OR hash mismatch:
  - Read `/workspace/<project>/AGENTS.md` and `/workspace/<project>/SOUL.md` (if exist).
  - Extract the specific rule section for this key.
  - Call `memory_replace(project_{project}_rules_{key}, <extracted_rule>, metadata: {hash: <rules_hash>})`.
  - Use the rule in current task context.
- If any rule is missing and cannot be extracted → `kanban_block` with reason.

## Memory schema

**Index entry** (created by orchestrator):
memory_replace(project_{project}_rules_index, {
keys: ["ui-conventions", "api-standards", "testing-patterns"],
hash: "a1b2c3d4...",
updated_at: "2026-08-13T10:00:00Z"
})

**Rule entry** (created by coder on demand, or by orchestrator if proactive):
memory_replace(project_{project}_rules_ui-conventions, "content...", metadata: {hash: "a1b2c3d4..."})

**Cache invalidation logic**:
```python
if stored_hash != metadata.rules_hash:
    # reload from disk and update memory
    memory_replace(...)
```
