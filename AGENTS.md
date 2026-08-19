# AGENTS.md

## What this repo is

Deployment + instruction repo for a 4-container Hermes system (`nousresearch/hermes-agent` Docker images) orchestrating work via a Kanban board. It is **not application code**: no `package.json`, no tests, no lint, no build. "Code" here = Hermes skills (Markdown instructions), compose config, and bash scripts. There is nothing to run locally except Docker.

## Layout

- `profiles/<profile>/` — one dir per agent role:
  - `config.yaml` — model settings (DeepSeek: `deepseek-chat` / `deepseek-reasoner`) + `mcp_servers` (dense-mem RAG)
  - `skills/<skill-name>/SKILL.md` — one skill per folder
- `scripts/` — `init.sh`, `backup.sh`, `memory-bootstrap.sh`, `load-secrets.sh`, `cloud-init.sh` (all bash)
- `docker-compose.yml` — 7 services: 4 Hermes workers + the dense-mem memory stack (`memory-db`, `embedding`, `dense-mem`); declares a top-level `secrets:` block
- `secrets/` (gitignored, created by `make init`) — one plain file per secret value; mounted into `/run/secrets/<name>`

## How the system runs

- Each worker container runs `hermes kanban work --profile <p> --role <r> --skill <s> --loop --interval 5`; the Telegram gateway runs `hermes gateway run --profile dispatcher --skill command-handler --gateway telegram`. Service/role/skill wiring lives only in `docker-compose.yml`.
  - `dispatcher` → role `orchestrator`, skill `orchestrate-task` (decomposes tasks into component sub-tasks, coordinates one shared feature branch + final PR task)
  - `coder` → role `developer`, skill `execute-task`, flag `--skip_context_files` (executes components or creates the PR)
  - `qa` → role `qa`, skill `execute-qa-task` (runs review-and-merge / release-to-main / deploy-ftp)
  - `telegram-bot` → gateway `telegram`, skill `command-handler` (uses the dispatcher secrets + `HERMES_PROFILE=dispatcher`)
- **The containers install profiles from this GitHub repo at startup** (`hermes profile install <repo url> --alias <profile>`). To ship changes: commit + push, then on the server `git pull` first (refreshes the local clone that docker compose reads for compose/scripts) and recreate containers (`docker compose up -d --force-recreate`); `make update-profiles` alone suffices for skill-only changes (runs `hermes profile update` in running containers, no restart).
- All services share the volume `./hermes-data:/home/hermes/.hermes` (Kanban DB + agent memory). Do not remove it from a service — it is the only coordination channel.
- **Memory layer (RAG E-pool)**: each Hermes profile registers the `dense_mem` MCP server in `config.yaml` (`mcp_servers.dense_mem`, HTTP at `http://dense-mem:8080/mcp`). Hermes prefixes its tools `mcp_dense_mem_*` (e.g. `mcp_dense_mem_recall_memory`). Workers depend on `dense-mem` being healthy before starting. The stack: `memory-db` (PostgreSQL + pgvector, the durable store), `embedding` (TEI `all-MiniLM-L6-v2`, OpenAI-compatible `/v1/embeddings`), `dense-mem` (MCP server + control portal on `:8090`). Infra secrets (`postgres_password`, `control_portal_token`, `ai_verifier_api_key`) live in `secrets/`; per-worker profile API keys (`dense_mem_<profile>`) are created via `scripts/memory-bootstrap.sh`.
- Healthchecks use `hermes kanban status` (gateway container uses `hermes gateway status`); the memory stack uses `pg_isready` / `curl /health` / the dense-mem image healthcheck.
- **HITL notifications**: the `telegram-bot` container runs `scripts/notify-blocked.sh` as a background process alongside the gateway. It polls blocked tasks every 30s, finds ones with `approval-required:` in the reason, and sends a Telegram message to the task owner (`chat_id` from metadata) with the task ID and a reminder to `/unblock`. All Telegram communication (inbound commands + outbound notifications) is centralized in the `telegram-bot` service.

## Commands

All targets use bash + `docker compose` (v2):

- `make init` — creates `workspace/`, `backups/`, `secrets/` (empty placeholder files, never overwrites existing) and a generated `secrets/README.md`. Note: compose mounts `./hermes-data` (Kanban DB + agent memory), which **is** in `.gitignore`.
- `make check-secrets` — preflight: every secret file declared in compose exists and required ones are non-empty (optional: `ftp_*`, `vercel_org_id`, `vercel_project_id`)
- `make up` / `make down` / `make logs` — lifecycle (`make up` runs `check-secrets` first; workers start only after `dense-mem` is healthy; containers fail fast on unreadable secret files)
- `make backup` — Kanban dump + dense-mem PostgreSQL `pg_dump` into `backups/`, keeps 7 days (also cron'd on server at 02:00 via `cloud-init.sh`)
- `make memory-bootstrap` — creates the dense-mem team + per-worker profiles and prints the keys to store as `secrets/dense_mem_<profile>`
- `make update-profiles` — reinstall profiles in running containers

## Secrets

- Values live in `secrets/` (gitignored): one plain file per secret, no comments inside (the whole file content IS the value; trailing newline stripped by the loader). `make init` creates empty placeholders; fill them with `printf '%s' '<value>' > secrets/<name>`. Compose mounts each into `/run/secrets/<name>` (per-service grants in the service's `secrets:` list; `secrets:` is a bind-mounted file, **no encryption** — it's a K8s Secret-like abstraction, not a vault).
- Containers run `scripts/load-secrets.sh` before the real command: it implements the Docker `*_FILE` convention — for every `VAR_FILE` env var it `export VAR="$(cat $VAR_FILE)"`. Compose sets `VAR_FILE=/run/secrets/<name>`; Hermes/dense-mem read plain `VAR`. The loader is strict (unreadable/missing file aborts the container).
- `dense-mem` uses an entrypoint wrapper (`entrypoint: [.. load-secrets.sh && exec /app/docker-entrypoint.sh ..]`) because its own image entrypoint builds `POSTGRES_DSN` from env at startup; `memory-db` uses the image-native `POSTGRES_PASSWORD_FILE`. Non-secret config (URLs, model names, `POSTGRES_USER/DB`, `AI_API_KEY=tei` dummy for the local TEI) is hardcoded in compose `environment:`.
- `scripts/check-secrets.sh` (run by `make up` / `make check-secrets`) fails before start if a required secret file is empty; optional files (`ftp_*`, `vercel_org_id`, `vercel_project_id`) may stay empty. A new secret = add a file in `secrets/` + an entry in compose `secrets:` + a `*_FILE` grant on the services that need it.

On Windows: Makefile and `scripts/*.sh` are bash — run them under WSL/git-bash, or run the underlying docker commands manually. There is no test/lint step; sanity-check with `docker compose config`.

## Editing skills

- Skill = `SKILL.md` with YAML frontmatter: `name` (must match the folder), `description`, `license`, optional `metadata.hermes.tags` / `related_skills`.
- **Language convention:** all documentation and skills are written in English.
- Adding a new profile requires touching all of: new `profiles/<name>/` (config.yaml, skills/), a service block in `docker-compose.yml` (with its `secrets:` grants + `*_FILE` envs), and the loop in `scripts/init.sh`.

## Kanban conventions (referenced throughout skills)

- The frontend stack is **standardized** and installed by `project-init`: React + React Router + Zustand + TypeScript + Vite + MUI + React Hook Form + Zod + TanStack Query + GSAP + Three.js/R3F + Vitest + MSW + Biome + Storybook (full table in README). All coder skills must target this stack only (e.g. no Tailwind, no ESLint/Prettier). `setup-ci` builds against it (`npm run lint` / `npm run test` / `npm run build`).
- AI models are not fixed globally: each profile sets a default model in `config.yaml`, and every skill invocation may specify a model.
- `project-init` writes an `AGENTS.md` into the project repo listing the stack, commands, and the Hermes skills that apply to it.
- Tasks carry `metadata.project`, `assignee` (role name: `orchestrator` / `coder` / `qa`), `chat_id`, and a `type` (`feature` / `bugfix` / `init` / `ui` / `content` / `integration` / `review` / `release` / `deploy`).
- The loops pick up tasks with status `ready`. Statuses in use are `ready`, `blocked`, `done`, `cancelled` (`/cancel`).
- Orchestration pattern (`orchestrate-task`): parent task (`assignee: orchestrator`, `ready`) is decomposed into component sub-tasks (`metadata.component: true`, `assignee: coder`, `ready`) plus one final PR task (`metadata.pr_creation: true`, `status: blocked`), all linked via `kanban_link`; the PR task is dependency-blocked on the components (`kanban_link --block`) and becomes `ready` once all are `done`. `orchestrate-task` runs once per task and never polls.
- **Architecture-first decomposition**: orchestrator decomposes tasks using Atomic Design vocabulary (atom/molecule/organism/template/page) and behavioral language (scroll-triggered, animated, responsive). It produces architectural tags per component (`metadata.tags`). The coder discovers the right skill by matching tags via `skill_discover(tags)`. This keeps the orchestrator skill-agnostic: new skills can be added without changing the decomposition prompt.
- Coder (`execute-task`) executes `component: true` tasks, the `pr_creation: true` task, or `type: review` fix loops; after a PR is created it hands off to QA via a `type: review` task (`assignee: qa`, `ready`). QA (`execute-qa-task`) dispatches on task type: `type: review` runs `review-and-merge` (CI → merge to `dev` → Vercel staging via `deploy-vercel`) and ends in `done` (success — merge + staging deploy), `ready` back to coder at high priority (needs fixes, `execute-task` routes to `references/review-fix.md`), or `blocked` (failure); `type: release` (created by the Telegram `/release` command) runs `release-to-main` (PR dev → main → blocked for HITL approval → merge after `/unblock`); `type: deploy` (created by the Telegram `/deploy-ftp` command) runs `deploy-ftp` on `main` and ends in `done` or `blocked`. The review task loops coder ↔ QA until QA passes. Production FTP deploy happens only via `/deploy-ftp` — merged PRs never FTP-deploy.
- PR branch convention: `feature/<task_id>-<sanitized_title>`, shared by all component sub-tasks.
- Project rules are cached in the RAG E-pool per git hash: the orchestrator extracts `AGENTS.md` / `SOUL.md` into tagged records (`project-rules:<project>`, `rules:<key>` per rule, plus a `rules-index` record carrying the `rules_hash`). `rules_hash` + `rules_keys_needed` travel in task metadata and invalidate the cache; the disk `AGENTS.md` / `SOUL.md` is the deterministic fallback. Rule records are written only by the orchestrator; `--skip_context_files` on the coder avoids memory overload.
- **Experience memory (E-pool, dense-mem RAG)**: recall before executing (`mcp_dense_mem_recall_memory` in `orchestrate-task` step 4 and coder `references/rag.md`), remember after success (coder after a completed component, QA with verified/high-confidence evidence after review passes), correct on failure (coder traces and retracts its own wrong evidence in the fix loop; QA `correct_relationship`/`retract_evidence` for qa-owned records). Tagged rules records win over untagged experience; recalled templates still must pass validation; **every memory call is best-effort and must never block a task**. Dense-mem enforces ownership: a profile can only correct/retract its own submitted evidence. `config.yaml` whitelists which MCP tools each profile exposes.
- **Task prioritization (Pattern #20)**: tasks carry `metadata.priority_score` (numeric) computed from a formula: `age_urgency + type_weight + iteration_penalty + dependency_bonus`. The command-handler stamps an initial score at creation (age=0). The `prioritize-tasks` skill (dispatcher) re-scores all ready tasks periodically. Type weights: bugfix/release=4, deploy/review=3, feature/ui/integration=2, content/init=1. Age urgency grows with time (capped at 5). Iteration penalty adds +2 per review bounce. Dependency bonus adds +3 if the task blocks others. Labels derived from score: ≥8 critical, ≥5 high, ≥3 normal, <3 low. The score is advisory metadata — it does not change task status but signals relative priority for human operators and future priority-aware routing.
- **Exploration on repeated failures (Pattern #21)**: when a review task bounces between coder and QA ≥3 times (`metadata.review_iterations`), the system triggers exploration escalation. QA moves the task to the orchestrator (not back to coder) for re-decomposition with a different strategy. The coder also detects this and flags for exploration via `metadata.exploration_flag`. The orchestrator receives the task with `exploration_triggered: true` and high `priority_score` (+5 bonus) to ensure it is processed next. The re-decomposition prompt explicitly requests alternative approaches: simpler components, different tech choices, or smaller pieces. Metrics: daily-stats tracks exploration triggers and high-iteration tasks.
