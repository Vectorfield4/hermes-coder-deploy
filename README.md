# Hermes Coder Deploy

Multi-agent development system built on Hermes Agent, orchestrating work through a Kanban board.

## 🐳 Services

### Workers

| Service | Profile | Role | Command | Skill |
|---------|---------|------|---------|-------|
| **dispatcher** | dispatcher | `orchestrator` | `hermes kanban work --loop` | `orchestrate-task` |
| **coder** | coder | `developer` | `hermes kanban work --loop --skip_context_files` | `execute-task` |
| **qa** | qa | `qa` | `hermes kanban work --loop` | `execute-qa-task` |
| **telegram-bot** | dispatcher | — | `hermes gateway run --gateway telegram` | `command-handler` |

### Memory Stack

| Service | Command | Purpose |
|---------|---------|---------|
| **memory-db** | PostgreSQL + pgvector | Durable memory store |
| **embedding** | TEI `all-MiniLM-L6-v2` (port 8081) | Embeddings for RAG |
| **dense-mem** | MCP memory server (`:8080/mcp`, control portal `:8090`) | RAG E-pool |

All services share the `hermes-data` volume (Kanban + agent memory) — it is the only coordination channel. Workers start only after `dense-mem` is healthy.

## 🧠 Skills

Each skill is a Markdown instruction for the agent. Skills live in `profiles/<profile>/skills/<skill-name>/SKILL.md`.

### dispatcher
- **command-handler** — Telegram gateway: `/task`, `/project add`, `/status`, `/cancel`, `/release`, `/deploy-ftp`, `/unblock`, `/help`. Stamps initial `priority_score` on task creation.
- **orchestrate-task** — decomposes tasks into component sub-tasks (UI / content / integration) with `acceptance_criteria`, coordinates a shared branch and final PR task. Recalls anti-patterns before decomposing; handles exploration re-decomposition.
- **prioritize-tasks** — composite scoring (type + aging + iterations + unblocking). Advisory metadata for operators.

### coder
- **execute-task** — dispatches to: component execution, project init, PR creation, or review-fix loop. Routes `type: review` to `references/review-fix.md`.
- **create-pr** — validation, commit, push, PR creation to `dev`.
- **project-init** / **setup-ci** — project initialization (links Vercel for staging).
- **frontend-stack** — reference hub for the standardized stack (15 library references via `skill_view`).
- Specialized: **ui-architect**, **ui-implementer**, **content-strategist**, **integration-specialist**, **technical-planner**, **narrative-designer**, **simple-task-executor**, **threejs-scene-builder**.

### qa
- **execute-qa-task** — dispatches by type: `review` → review-and-merge (loops coder↔QA), `release` → release-to-main (HITL gate), `deploy` → deploy-ftp. Triggers exploration escalation after ≥3 review iterations.
- **review-and-merge** — CI check (10 min wait), code review, squash merge to `dev`, Vercel staging deploy.
- **release-to-main** — PR dev→main, blocked for human approval, merge after `/unblock`, build, GitHub Release.
- **deploy-vercel** / **deploy-ftp** — staging and production deploys.
- **pr-judge** — scores PRs 1–10, feeds verified templates and anti-patterns to the E-pool.
- **resolve-merge-conflict** — automatic resolution via `git merge --strategy-option theirs`.

## 🔄 Task Flow

```
/task → orchestrator → decompose into components → coder (parallel) → PR → QA review
                                                                        ↓
                                                              ┌─── PASS → merge to dev → Vercel staging
                                                              │
                                                              └─── FAIL → coder fix → QA re-review
                                                                                       ↓
                                                                              ≥3 iterations → EXPLORATION
                                                                                               ↓
                                                                                         orchestrator re-decompose
```

**Release:** `/release` → QA creates PR dev→main → blocked (HITL) → `/unblock` → merge → build → GitHub Release.
**Deploy:** `/deploy-ftp` → QA downloads release zip → FTP to server.

## 🧠 Memory Layer (RAG E-pool)

Two-layer memory via **dense-mem** MCP server (PostgreSQL + pgvector + TEI embeddings).

### Layer 1: Project Rules (authoritative)
- Orchestrator extracts `AGENTS.md` / `SOUL.md` into tagged `project-rules:<project>` records, keyed by `rules_hash` (git commit hash).
- Coder/QA recall via `references/memory.md`. Disk files are the deterministic fallback.

### Layer 2: Experience (advisory)
- **Recall** before executing: similar past solutions, patterns, pitfalls.
- **Remember** after success: compressed summaries (never raw source).
- **Anti-patterns**: recalled before execution — known failures are not repeated.
- **Exploration anti-patterns** (`tags: ["anti-pattern", "exploration"]`): stored by QA/coder when iteration ≥ 3. Orchestrator recalls these as **authoritative avoidance constraints** before re-decomposition.
- **Correct on failure**: coder retracts its own wrong evidence; QA retracts its own. Ownership enforced by dense-mem.

**All memory calls are best-effort — never block a task.**

### Stack

`memory-db` (PostgreSQL 18 + pgvector) → `embedding` (TEI `all-MiniLM-L6-v2`, 384-dim) → `dense-mem` (MCP `:8080/mcp`, control portal `:8090`).

## 🔐 Secrets

One plain file per value in `secrets/` (gitignored). `make init` creates empty placeholders.

- Compose mounts each into `/run/secrets/<name>` (K8s-style file mount, **not encrypted**).
- `load-secrets.sh` implements Docker `*_FILE` convention. Fails fast on missing files.
- `check-secrets.sh` (run by `make up`) validates required secrets are non-empty.
- Required: `telegram_bot_token`, `github_token`, `vercel_token`, `openai_api_key`, `dense_mem_{dispatcher,coder,qa}`, `postgres_password`, `control_portal_token`, `ai_verifier_api_key`. Optional: `ftp_*`, `vercel_org_id` / `vercel_project_id`.

## 🧱 Core Stack

Installed by `project-init`. All development targets this stack only.

| Component | Purpose |
|-----------|---------|
| React + TypeScript | UI + typing |
| Vite | Build tool |
| Zustand | State management |
| MUI | UI components |
| React Hook Form + Zod | Forms + validation |
| TanStack Query | API fetching + caching |
| React Router | Routing |
| GSAP + Three.js/R3F | Animations + 3D |
| Vitest + MSW | Testing + API mocking |
| Biome | Linter + Formatter |
| Storybook | Component docs |

## 🚀 Deployment

### Vercel staging (automatic)
Every PR merged by QA to `dev` → `deploy-vercel` creates a staging preview. `project-init` links Vercel automatically when `VERCEL_TOKEN` is set.

### Production FTP (on demand)
`/deploy-ftp <project>` → QA downloads latest GitHub Release zip → FTP to server. Requires `ftp_*` in `secrets/`.

### Server setup
1. Paste `cloud-init.sh` into Timeweb Cloud server creation.
2. Fill `secrets/` after boot.
3. `bash scripts/memory-bootstrap.sh` → store API keys in `secrets/dense_mem_*`.
4. `make up`.

## 📊 Eval & Observability

### Metrics

| Metric | Source |
|--------|--------|
| Task Success Rate (TSR) | `done` / total tasks |
| TSR Drift | 7-day rolling avg vs today (alert if >10% drop) |
| Cost Proxy | Steps + retries from `[outcome=success]` tags |
| Review Iterations | `task_runs` distinct profile count per review task |
| Per-type Success Rate | `GROUP BY metadata.type` |
| pass@k | Consecutive `done` streak |
| Prioritization | Scored ready tasks count |
| Exploration | Trigger count + high-iteration tasks (≥3 rounds) |

### Structured outcome logging

```bash
kanban_complete --comment "[outcome=success] <summary> | steps=<N> | retries=<N>"
```

### Daily stats

```bash
make daily-stats  # requires TELEGRAM_CHAT_ID env var or argument
```

Sends to Telegram: task counts, completed/blocked lists, memory stats, trajectory warnings, cost proxy, TSR drift, per-type breakdown, pass@k, prioritization, exploration triggers. Cron:
```
0 9 * * * cd /root/hermes-coder-deploy && TELEGRAM_CHAT_ID=<id> make daily-stats
```

## ✅ Best Practices

| Pattern | Implementation |
|---------|----------------|
| **Prompt Chaining** | Skills are fixed linear pipelines with no branching ambiguity. |
| **Routing** | QA dispatches by `metadata.type`; orchestrator classifies by component type. |
| **Parallelization** | Component sub-tasks run in parallel on separate git worktrees per shared branch. |
| **Reflection** | Three-tier check: coder self-review (4-dimension rubric), QA review cycle, pr-judge scoring (≥7 → template, ≤4 → anti-pattern). |
| **Tool Use** | Kanban, shell, MCP memory, skill composition, file I/O, delegation — 15+ tool categories. |
| **Planning** | Orchestrator decomposes with `acceptance_criteria` (2–5 testable conditions) and `rules_keys_needed` per component. |
| **Multi-Agent** | 4 containers, 3 roles (orchestrator / coder / qa) with role-based MCP tool whitelisting. |
| **Memory** | Two-layer E-pool: rules cache (authoritative, keyed by git hash) and experience (advisory, per-profile ownership). |
| **Learning** | pr-judge scores PRs 1–10; high scores saved as templates, low scores retracted as anti-patterns. |
| **MCP** | dense-mem MCP server with per-profile tool access control in `config.yaml`. |
| **Goal Monitoring** | Orchestrator sets acceptance criteria; QA verifies each against the codebase. |
| **Exception Handling** | Retry protocol (3 attempts, exponential backoff), transient/permanent classification, heartbeat, idempotent resume. |
| **Human-in-the-Loop** | Release gate (`/release` → blocked → `/unblock`), Telegram notifications, full command set. |
| **RAG** | Recall before execution; rules cache with git-hash invalidation; anti-pattern recall prevents repeating failures. |
| **Resource-Aware** | `deepseek-reasoner` for planning/review, `deepseek-chat` for implementation. |
| **Guardrails** | Input validation (dangerous tokens blocked), MCP tool whitelisting, ownership-based memory edit control. |
| **Evaluation** | Structured outcome tags, daily stats (TSR, drift, cost, pass@k, per-type success). |
| **Prioritization** | Composite scoring: `type_weight + aging + iteration_boost + unblock_bonus`. Anti-starvation aging capped at 5. |
| **Exploration** | After ≥3 review iterations: anti-patterns stored, task escalates to orchestrator for re-decomposition. |
