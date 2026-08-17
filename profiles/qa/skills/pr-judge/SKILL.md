---
name: pr-judge
description: Evaluates a PR against a quality rubric (code quality, tests, security, docs) and returns a score 1-10 with breakdown.
license: MIT
metadata:
  hermes:
    tags: [qa, judge, review, quality]
    related_skills: [execute-qa-task, review-and-merge]
---

# PR Judge

## Overview
Automated quality evaluation of a PR diff against a fixed rubric. Called by `execute-qa-task` after `review-and-merge` succeeds, before the final pass/fail decision. The score feeds into memory decisions: high scores → verified templates, low scores → anti-patterns.

## Input
- `pr_url` — PR URL from task metadata
- `branch` — feature branch name
- `project` — project name
- `rules_context` — project-specific conventions (from RAG cache)

## Rubric (score 1–10)

| Dimension | Weight | What to check |
|-----------|--------|---------------|
| **Code quality** | 25% | Readability, naming, DRY, separation of concerns, no dead code, consistent style |
| **Tests** | 25% | Coverage of new logic, edge cases, meaningful assertions, no skipped tests |
| **Security** | 25% | No hardcoded secrets, input validation, auth/authz checks, no injection vectors |
| **Docs & conventions** | 25% | AGENTS.md adherence, JSDoc/TSDoc where needed, no TODO-blockers, changelog if needed |

## Instructions

### 1. Get the diff
```bash
gh pr diff <pr_number> --repo <repo>
```
If the diff is too large (>3000 lines), focus on changed files only:
```bash
gh pr diff <pr_number> --name-only
```
Then read each changed file individually.

### 2. Evaluate against rubric
For each dimension, assess the diff and assign a sub-score (1–10):
- **1–3**: Significant issues, would block deployment
- **4–5**: Needs improvement, notable gaps
- **6–7**: Acceptable, minor improvements possible
- **8–10**: Excellent, no issues found

### 3. Compute overall score
```
overall = round(code_quality * 0.25 + tests * 0.25 + security * 0.25 + docs * 0.25)
```

### 4. Return structured result
Output the result as a single line for parsing:
```
[JUDGE_SCORE=N] summary | quality=N tests=N security=N docs=N
```
Where N is the integer score (1–10).

If any dimension scores ≤ 3, prefix with a warning:
```
[JUDGE_SCORE=N] ⚠️ <dimension> is critically low: <reason> | quality=N tests=N security=N docs=N
```

## Score Thresholds (used by execute-qa-task)

| Score | Action |
|-------|--------|
| ≥ 7 | **Verified** — pattern saved to E-pool as high-confidence template |
| 5–6 | **Neutral** — no memory action, review decides normally |
| ≤ 4 | **Anti-pattern** — retract positive evidence, save as anti-pattern |

## Tools
- `gh pr diff`, `gh pr view` — read PR data
- No memory calls — memory decisions are made by `execute-qa-task` based on the score

## Common Pitfalls
- **Over-scoring**: be strict — a 7 means genuinely good code, not "good enough"
- **Ignoring security**: a single hardcoded secret = security score ≤ 2 regardless of other quality
- **Missing test gaps**: code that changes business logic without tests = tests score ≤ 3

## Verification
- [ ] Diff was retrieved successfully
- [ ] All 4 dimensions were evaluated
- [ ] Overall score matches the formula
- [ ] Result is in parseable format `[JUDGE_SCORE=N] ...`
