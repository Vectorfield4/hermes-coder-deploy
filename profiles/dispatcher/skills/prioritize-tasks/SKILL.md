---
name: prioritize-tasks
description: Scores ready tasks by composite weight (type value + aging + iterations + dependency unblocking). Deterministic — no LLM needed.
metadata:
  hermes:
    tags: [dispatcher, prioritization]
---

# Prioritize Tasks

Score every `ready` task so the highest-value work surfaces first. The scoring is deterministic arithmetic — no LLM call.

## Formula

```
score = type_weight + aging + iteration_boost + unblock_bonus
```

| Signal | Calculation | Range | Why |
|--------|-------------|-------|-----|
| **type_weight** | lookup table below | 1–4 | Bugfixes/releases > features > content |
| **aging** | `min(age_minutes / 30, 5)` | 0–5 | Anti-starvation: old tasks rise |
| **iteration_boost** | `review_iterations × 2` | 0–∞ | Repeated bounces signal urgency |
| **unblock_bonus** | `3` if blocked tasks depend on this, else `0` | 0 or 3 | Unblock the pipeline first |

### Type weights

| Type | Weight |
|------|--------|
| bugfix, release | 4 |
| deploy, review | 3 |
| feature, ui, integration | 2 |
| content, init | 1 |

## How to apply

Run once at the start of each orchestrator cycle:

1. `kanban_list(status: ready)` → if empty, stop.
2. For each task compute `score` using the formula.
3. `kanban_update(task_id, metadata: { priority_score: <score> })` — advisory, no status change.
4. Pick the task with the highest score.

When QA bounces a task back, increment `metadata.review_iterations` by 1 and add `+1` to `priority_score` — the aging term will handle the rest on next cycle.

## Notes

- The Hermes `kanban work` loop picks by `status: ready` only. The score is a visible signal for operators and future routing.
- Per-signal weights are capped (max ~5) to prevent any single signal from dominating.
