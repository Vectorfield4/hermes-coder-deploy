# AGENTS.md

## What this repo is

Deployment + instruction repo for a 4-container Hermes system (`nousresearch/hermes-agent` Docker images) orchestrating work via a Kanban board. It is **not application code**: no `package.json`, no tests, no lint, no build. "Code" here = Hermes skills (Markdown instructions), compose config, and bash scripts. There is nothing to run locally except Docker.

## Layout

- `profiles/<profile>/` — one dir per agent role:
  - `config.yaml` — model settings (DeepSeek: `deepseek-chat` / `deepseek-reasoner`) + `mcp_servers` (dense-mem RAG)
  - `.env.example` — required secrets template; real `.env` is gitignored
  - `skills/<skill-name>/SKILL.md` — one skill per folder
- `scripts/` — `init.sh`, `backup.sh`, `memory-bootstrap.sh`, `cloud-init.sh` (all bash)
- `docker-compose.yml` — 7 services: 4 Hermes workers + the dense-mem memory stack (`memory-db`, `embedding`, `dense-mem`)
- `.env` (root, gitignored) — secrets for the dense-mem stack (copied from `.env.example` by `make init`)

## How the system runs

- Each worker container runs `hermes kanban work --profile <p> --role <r> --skill <s> --loop --interval 5`; the Telegram gateway runs `hermes gateway run --profile dispatcher --skill command-handler --gateway telegram`. Service/role/skill wiring lives only in `docker-compose.yml`.
  - `dispatcher` → role `orchestrator`, skill `orchestrate-task` (decomposes tasks into component sub-tasks, coordinates one shared feature branch + final PR task)
  - `coder` → role `developer`, skill `execute-task`, flag `--skip_context_files` (executes components or creates the PR)
  - `qa` → role `qa`, skill `execute-qa-task` (runs review-and-deploy)
  - `telegram-bot` → gateway `telegram`, skill `command-handler` (uses dispatcher `.env` + `HERMES_PROFILE=dispatcher`)
- **The containers install profiles from this GitHub repo at startup** (`hermes profile install <repo url> --alias <profile>`). To ship changes: commit + push, then on the server `git pull` first (refreshes the local clone that docker compose reads for `.env`/compose/scripts) and recreate containers (`docker compose up -d --force-recreate`); `make update-profiles` alone suffices for skill-only changes (runs `hermes profile update` in running containers, no restart).
- All services share the volume `./hermes-data:/home/hermes/.hermes` (Kanban DB + agent memory). Do not remove it from a service — it is the only coordination channel.
- **Memory layer (RAG E-pool)**: each Hermes profile registers the `dense_mem` MCP server in `config.yaml` (`mcp_servers.dense_mem`, HTTP at `http://dense-mem:8080/mcp`). Hermes prefixes its tools `mcp_dense_mem_*` (e.g. `mcp_dense_mem_recall_memory`). Workers depend on `dense-mem` being healthy before starting. The stack: `memory-db` (PostgreSQL + pgvector, the durable store), `embedding` (TEI `all-MiniLM-L6-v2`, OpenAI-compatible `/v1/embeddings`), `dense-mem` (MCP server + control portal on `:8090`). Infra secrets live in the root `.env`; per-worker profile API keys (`DENSE_MEM_API_KEY`) are created via `scripts/memory-bootstrap.sh`.
- Healthchecks use `hermes kanban status` (gateway container uses `hermes gateway status`); the memory stack uses `pg_isready` / `curl /health` / the dense-mem image healthcheck.

## Commands

All targets use bash + `docker compose` (v2):

- `make init` — creates `data/`, `workspace/`, `backups/` and copies `.env.example` → `.env` (root + each profile). Note: compose mounts `./hermes-data`, not `./data/`; the `hermes-data/` volume is **not** in `.gitignore` — never commit it (holds the Kanban DB + agent memory).
- `make up` / `make down` / `make logs` — lifecycle (workers start only after `dense-mem` is healthy)
- `make backup` — Kanban dump + dense-mem PostgreSQL `pg_dump` into `backups/`, keeps 7 days (also cron'd on server at 02:00 via `cloud-init.sh`)
- `make memory-bootstrap` — creates the dense-mem team + per-worker profiles and prints the `DENSE_MEM_API_KEY`s
- `make update-profiles` — reinstall profiles in running containers

On Windows: Makefile and `scripts/*.sh` are bash — run them under WSL/git-bash, or run the underlying docker commands manually. There is no test/lint step; sanity-check with `docker compose config`.

## Editing skills

- Skill = `SKILL.md` with YAML frontmatter: `name` (must match the folder), `description`, `license`, optional `metadata.hermes.tags` / `related_skills`.
- **Language convention:** all documentation and skills are written in English.
- Adding a new profile requires touching all of: new `profiles/<name>/` (config.yaml, .env.example, skills/), a service block in `docker-compose.yml`, and the loop in `scripts/init.sh`.

## Kanban conventions (referenced throughout skills)

- The frontend stack is **standardized** and installed by `project-init`: React + React Router + Zustand + TypeScript + Vite + MUI + React Hook Form + Zod + TanStack Query + GSAP + Three.js/R3F + Vitest + MSW + Biome + Storybook (full table in README). All coder skills must target this stack only (e.g. no Tailwind, no ESLint/Prettier). `setup-ci` builds against it (`npm run lint` / `npm run test` / `npm run build`).
- AI models are not fixed globally: each profile sets a default model in `config.yaml`, and every skill invocation may specify a model.
- `project-init` writes an `AGENTS.md` into the project repo listing the stack, commands, and the Hermes skills that apply to it.
- Tasks carry `metadata.project`, `assignee` (role name: `orchestrator` / `coder` / `qa`), `chat_id`, and a `type` (`feature` / `bugfix` / `init` / `ui` / `content` / `integration` / `review` / `deploy`).
- The loops pick up tasks with status `ready`. Statuses in use are `ready`, `blocked`, `done`, `cancelled` (`/cancel`).
- Orchestration pattern (`orchestrate-task`): parent task (`assignee: orchestrator`, `ready`) is decomposed into component sub-tasks (`metadata.component: true`, `assignee: coder`, `ready`) plus one final PR task (`metadata.pr_creation: true`, `status: blocked`), all linked via `kanban_link`; the PR task is dependency-blocked on the components (`kanban_link --block`) and becomes `ready` once all are `done`. `orchestrate-task` runs once per task and never polls.
- Coder (`execute-task`) executes `component: true` tasks, the `pr_creation: true` task, or `type: review` fix loops; after a PR is created it hands off to QA via a `type: review` task (`assignee: qa`, `ready`). QA (`execute-qa-task`) dispatches on task type: `type: review` runs `review-and-deploy` (CI → merge to `main` → Vercel staging via `deploy-vercel`) and ends in `done` (success — merge + staging deploy), `ready` back to coder at high priority (needs fixes, `execute-task` routes to `references/review-fix.md`), or `blocked` (failure); `type: deploy` (created by the Telegram `/deploy` command) runs `deploy-ftp` on `main` and ends in `done` or `blocked`. The review task loops coder ↔ QA until QA passes. Production FTP deploy happens only via `/deploy` — merged PRs never FTP-deploy.
- PR branch convention: `feature/<task_id>-<sanitized_title>`, shared by all component sub-tasks.
- Project rules are cached in the RAG E-pool per git hash: the orchestrator extracts `AGENTS.md` / `SOUL.md` into tagged records (`project-rules:<project>`, `rules:<key>` per rule, plus a `rules-index` record carrying the `rules_hash`). `rules_hash` + `rules_keys_needed` travel in task metadata and invalidate the cache; the disk `AGENTS.md` / `SOUL.md` is the deterministic fallback. Rule records are written only by the orchestrator; `--skip_context_files` on the coder avoids memory overload.
- **Experience memory (E-pool, dense-mem RAG)**: recall before executing (`mcp_dense_mem_recall_memory` in `orchestrate-task` step 4 and coder `references/rag.md`), remember after success (coder after a completed component, QA with verified/high-confidence evidence after review passes), correct on failure (coder traces and retracts its own wrong evidence in the fix loop; QA `correct_relationship`/`retract_evidence` for qa-owned records). Tagged rules records win over untagged experience; recalled templates still must pass validation; **every memory call is best-effort and must never block a task**. Dense-mem enforces ownership: a profile can only correct/retract its own submitted evidence. `config.yaml` whitelists which MCP tools each profile exposes.
