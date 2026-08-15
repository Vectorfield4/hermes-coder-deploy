# Hermes Coder Deploy

Multi-agent development system built on Hermes Agent, orchestrating work through a Kanban board.

## 🐳 Services

| Service | Profile | Role | Command | Skill |
|---------|---------|------|---------|-------|
| **dispatcher** | dispatcher | `orchestrator` | `hermes kanban work --loop` | `orchestrate-task` |
| **coder** | coder | `developer` | `hermes kanban work --loop --skip_context_files` | `execute-task` |
| **qa** | qa | `qa` | `hermes kanban work --loop` | `execute-qa-task` |
| **telegram-bot** | dispatcher | — | `hermes gateway run --gateway telegram` | `command-handler` |
| **memory-db** | — | — | PostgreSQL + pgvector | durable memory store |
| **embedding** | — | — | TEI `all-MiniLM-L6-v2` (port 8081) | embeddings for RAG |
| **dense-mem** | — | — | MCP memory server (`:8080/mcp`, control portal `:8090`) | RAG E-pool |

All services share the `hermes-data` volume (Kanban + agent memory) — it is the only coordination channel. Workers start only after `dense-mem` is healthy.

## 🧠 Skills

Each skill is a Markdown instruction for the agent. Skills live in `profiles/<profile>/skills/<skill-name>/SKILL.md`.

### dispatcher
- **command-handler** — handles the `/task`, `/project add`, `/status`, `/cancel`, `/deploy`, `/help` commands from Telegram; creates tasks for the orchestrator (or directly for the coder on `/project add`).
- **orchestrate-task** — decomposes a task into component sub-tasks (UI / content / integration), coordinates a single shared branch `feature/<task_id>-<title>` and a final PR task.

### coder
- **execute-task** — executes a single component sub-task (`component: true`), initializes projects (`type: init`), aggregates changes and creates a PR (`pr_creation: true`, then hands off to QA), or fixes QA findings (`type: review`).
- **create-pr** — validation (lint/tests), commit, push of the branch, PR creation.
- **project-init** / **setup-ci** — project initialization (for `type: init` tasks). `project-init` also links the repo to Vercel (`VERCEL_TOKEN`) so staging deploys work out of the box.
- **project-discover** — scans `/workspace`, reads project context (`AGENTS.md`, `.hermes.md`, etc.).
- **frontend-stack** — reference hub for the standardized stack; `references/` has a distilled page per library (React, React Router, Zustand, TypeScript, Vite, MUI, React Hook Form, Zod, TanStack Query, GSAP, Three.js/R3F, Vitest, MSW, Biome, Storybook). Loaded by the component skills via `skill_view` when writing code.
- Specialized: **ui-architect**, **ui-implementer**, **content-strategist**, **integration-specialist**, **technical-planner**, **narrative-designer**, **simple-task-executor**, **threejs-scene-builder**.

### qa
- **execute-qa-task** — dispatches on task type: `type: deploy` runs `deploy-ftp`; `type: review` runs `review-and-deploy`, returns the task to the coder as high priority (`ready`) when issues are found, or blocks it (`blocked`). The review task loops coder ↔ QA until QA passes.
- **review-and-deploy** — checks CI (waits up to 10 min), code review, merge (squash) to `main`, then deploys to Vercel staging via `deploy-vercel`.
- **deploy-vercel** — builds `main` and creates a Vercel staging/preview deployment using the Vercel CLI. Each project carries its link in `.vercel/project.json`; only `VERCEL_TOKEN` is needed in the QA profile.
- **deploy-ftp** — production FTP deploy of `main`, triggered on demand by the `/deploy` command.
- **resolve-merge-conflict** — automatic conflict resolution via `git merge --strategy-option theirs`.
- **cleanup-branch** — deletes the branch after completion.

## 🔄 How loops work

Each worker container runs an infinite loop via `hermes kanban work --profile <p> --role <r> --skill <s> --loop --interval 5` (polls Kanban every 5 seconds), and the Telegram gateway runs as a separate `telegram-bot` service. Service → role → skill wiring lives only in `docker-compose.yml`.

**Task flow:** `/task` in Telegram → `ready` task for the orchestrator → decomposition into sub-tasks → the coder executes components → the PR task creates a PR → QA reviews and merges to `main` → Vercel staging deploy.

## 🧠 Memory layer (RAG E-pool via dense-mem)

All three workers (and the Telegram gateway) connect to the **dense-mem** MCP server through `mcp_servers.dense_mem` in each profile's `config.yaml`. Hermes exposes its tools as `mcp_dense_mem_*` (e.g. `mcp_dense_mem_recall_memory`).

- **Recall before executing**: the dispatcher recalls similar past plans before decomposing (`orchestrate-task` step 4); the coder recalls patterns before implementing a component (`execute-task` → `references/rag.md`); QA can recall known pitfalls before reviewing.
- **Remember after success**: the coder stores a compressed summary after a completed component; QA stores verified/high-confidence evidence after a review passes.
- **Rules cache (project rules)**: the orchestrator extracts `AGENTS.md` / `SOUL.md` into tagged `project-rules:<project>` records in the E-pool (index + per-key), keyed by `rules_hash` carried in task metadata. Coder/QA recall the rules via `references/memory.md`; the disk files are the deterministic fallback. Rule records are authoritative over experience.
- **Correct on failure**: the coder traces and retires its own wrong evidence during the fix loop; dense-mem enforces ownership (a profile can only correct/retract its own submissions).
- Rules cache (AGENTS.md / SOUL.md) is authoritative; E-pool is advisory. Recalled templates still must pass validation. **Every memory call is best-effort and never blocks a task.**

Stack (in `docker-compose.yml`): `memory-db` (PostgreSQL + pgvector, durable store) → `embedding` (TEI, `all-MiniLM-L6-v2`, 384-dim) → `dense-mem` (MCP server + control portal). Infra secrets live in `secrets/` (see [Secrets](#-secrets)); per-worker profile API keys (`dense_mem_<profile>`) are created via `scripts/memory-bootstrap.sh`.

## 🔐 Secrets

All secret values live in `secrets/` (gitignored) as one plain file per value. `make init` creates empty placeholders plus a generated `secrets/README.md` describing each file; fill them with `printf '%s' '<value>' > secrets/<name>`.

- Compose declares the values in a top-level `secrets:` block and mounts each into `/run/secrets/<name>` for the services that grant it. It is a K8s Secret-like file mount, **not encrypted** — treat the host filesystem as trusted.
- Hermes and dense-mem read env vars, not files, so every container runs `scripts/load-secrets.sh` first: for each `<NAME>_FILE` env var it `export NAME="$(cat ...)"` (Docker `*_FILE` convention). The loader fails fast if a secret file is missing.
- `make up` runs `scripts/check-secrets.sh` first (`make check-secrets` for a standalone preflight): it fails before start if any secret file is missing or a **required** one is empty, so a fresh clone never silently starts with empty credentials. Optional secrets (`ftp_*`, `vercel_org_id`, `vercel_project_id`) may stay empty.
- `memory-db` uses the image-native `POSTGRES_PASSWORD_FILE`; `dense-mem` gets an entrypoint wrapper around its own `/app/docker-entrypoint.sh` because that script builds `POSTGRES_DSN` from env at startup. Non-secret config (URLs, model names, `POSTGRES_USER/DB`, `AI_API_KEY=tei` dummy for the local TEI) is hardcoded in compose `environment:`.
- Required: `telegram_bot_token`, `github_token`, `vercel_token`, `openai_api_key`, `dense_mem_{dispatcher,coder,qa}`, `postgres_password`, `control_portal_token`, `ai_verifier_api_key`. Optional: `ftp_{host,user,pass}` (only for `/deploy`), `vercel_org_id` / `vercel_project_id` (legacy link shortcut).

## 🧱 Core stack (installed by `project-init`)

The stack is standardized and installed automatically by `project-init` (a `type: init` task, created via `/project add`). All development tasks must target this stack.

| Component | Purpose |
|-----------|---------|
| **React** | UI library |
| **React Router** | Routing |
| **Zustand** | State management |
| **TypeScript** | Typing |
| **Vite** | Build tool |
| **MUI (Material-UI)** | UI components (atoms) |
| **React Hook Form** | Forms |
| **Zod** | Schema validation |
| **TanStack Query** | API data fetching and caching |
| **GSAP** | Animations |
| **Three.js** | 3D graphics |
| **React Three Fiber** | React wrapper for Three.js |
| **Jest / Vitest** | Testing |
| **MSW (Mock Service Worker)** | API mocking for tests |
| **Biome** | Linter + Formatter |
| **Storybook** | Component documentation and isolation |

- The stack is set up by the **project-init** and **setup-ci** skills; all coder component skills (ui-architect, ui-implementer, threejs-scene-builder, integration-specialist, content-strategist, narrative-designer, simple-task-executor, technical-planner) target only this stack.
- `project-init` writes an `AGENTS.md` into the project repository describing the stack, the commands, and the list of skills that apply to it.
- AI models are not fixed globally: each profile defines a default model in `config.yaml`, and any skill invocation may specify a specific model.

## 🚀 Deployment

### Vercel staging

Every PR merged by QA to `main` is automatically deployed to Vercel staging by the `deploy-vercel` skill. `project-init` links a new project to Vercel automatically when `VERCEL_TOKEN` is set in the coder profile. Setup:

1. Create a Vercel token (`VERCEL_TOKEN`) under Account → Tokens and set it in `secrets/vercel_token` (used by `project-init` in the coder and `deploy-vercel` in QA).
2. Ensure the Vercel project exists (import the repo in the dashboard, or `npx vercel project add <name>`).
3. On `/project add`, `project-init` links the repo and commits `.vercel/project.json` (orgId + projectId). To link manually later: `npx --yes vercel@latest link --yes --token "$VERCEL_TOKEN"` in the project and commit `.vercel/project.json`.
4. `secrets/vercel_org_id` / `secrets/vercel_project_id` are an optional shortcut: when set, `project-init` writes `.vercel/project.json` directly (no CLI linking needed).

### Production FTP (on demand)

Run `/deploy <project>` in Telegram → QA runs `deploy-ftp` (builds `main`, uploads to FTP). Requires `ftp_host`, `ftp_user`, `ftp_pass` in `secrets/`.

### Option 1: Automatic cloud-init (recommended)

1. In the Timeweb Cloud panel, when creating a server, find the **"Cloud-init"** field (Configuration tab).
2. Copy the contents of `cloud-init.sh` from this repository and paste it into the field.
3. Create the server.
4. Once the server has booted, connect via SSH and fill in the secrets (as shown in the cloud-init message): `telegram_bot_token`, `github_token`, `vercel_token`, `openai_api_key`, `postgres_password`, `control_portal_token`, `ai_verifier_api_key` in `secrets/` (plus the optional `ftp_*` / `vercel_org_id` / `vercel_project_id`).
5. Start the system with `make up`.
6. Create the dense-mem profiles and wire the workers:
   - `bash scripts/memory-bootstrap.sh` — creates the `hermes-coder` team + `dispatcher` / `coder` / `qa` profiles and prints an API key per profile.
   - Store each key: `printf '%s' '<api_key>' > secrets/dense_mem_<p>`.
   - `docker compose up -d --force-recreate` (workers pick up the MCP credentials).
7. Verify it works: `make logs`.

`cloud-init.sh` also enables **unattended security upgrades** (`unattended-upgrades`) and runs the stack under root's docker group (acceptable for a single-purpose VPS; the docker group is root-equivalent). Recommended hardening after boot: SSH key auth only (`PasswordAuthentication no` in `/etc/ssh/sshd_config`).

The Kanban **and** dense-mem PostgreSQL backups run automatically every day at 02:00. Adjust the schedule via `crontab -e` if needed.

## 📦 Updating

The containers install profiles from this GitHub repository on startup. To ship changes:

1. `git pull` on the server (updates the local clone that docker compose reads compose/scripts from).
2. `docker compose up -d --force-recreate` — for compose/script changes or a full profile reinstall.
3. `make update-profiles` — sufficient for skill-only changes (no restart).
