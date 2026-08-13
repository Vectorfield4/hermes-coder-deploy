# AGENTS.md

## What this repo is

Deployment + instruction repo for a 4-container Hermes system (`nousresearch/hermes-agent` Docker images) orchestrating work via a Kanban board. It is **not application code**: no `package.json`, no tests, no lint, no build. "Code" here = Hermes skills (Markdown instructions), compose config, and bash scripts. There is nothing to run locally except Docker.

## Layout

- `profiles/<profile>/` — one dir per agent role:
  - `config.yaml` — model settings (DeepSeek: `deepseek-chat` / `deepseek-reasoner`)
  - `.env.example` — required secrets template; real `.env` is gitignored
  - `skills/<skill-name>/SKILL.md` — one skill per folder (no `cron/` — see below)
- `scripts/` — `init.sh`, `backup.sh`, `cloud-init.sh` (all bash)
- `docker-compose.yml` — 4 services sharing one `hermes-data` volume

## How the system runs (important)

- Loops are NOT cron files anymore. Each worker container runs `hermes kanban work --profile <p> --role <r> --skill <s> --loop --interval 5`; the Telegram gateway runs `hermes gateway run --profile dispatcher --skill command-handler --gateway telegram`. Service/role/skill wiring lives only in `docker-compose.yml`.
  - `dispatcher` → role `orchestrator`, skill `orchestrate-task` (decomposes tasks into component sub-tasks, coordinates one shared feature branch + final PR task)
  - `coder` → role `developer`, skill `execute-task`, flag `--skip_context_files` (executes components or creates the PR)
  - `qa` → role `qa`, skill `execute-qa-task` (runs review-and-deploy)
  - `telegram-bot` → gateway `telegram`, skill `command-handler` (uses dispatcher `.env` + `HERMES_PROFILE=dispatcher`)
- **The containers install profiles from this GitHub repo at startup** (`hermes profile install <repo url> --alias <profile>`). To ship changes: commit + push, then on the server `git pull` first (refreshes the local clone that docker compose reads for `.env`/compose/scripts) and recreate containers (`docker compose up -d --force-recreate`); `make update-profiles` alone suffices for skill-only changes (runs `hermes profile update` in running containers, no restart).
- All services share the volume `./hermes-data:/home/hermes/.hermes` (Kanban DB + agent memory). Do not remove it from a service — it is the only coordination channel.
- Healthchecks use `hermes kanban status` (gateway container uses `hermes gateway status`).

## Commands

All targets use bash + `docker compose` (v2):

- `make init` — creates `data/`, `workspace/`, `backups/` and copies `.env.example` → `.env` per profile. Note: compose mounts `./hermes-data`, not `./data/`; the `hermes-data/` volume is **not** in `.gitignore` — never commit it (holds the Kanban DB + agent memory).
- `make up` / `make down` / `make logs` — lifecycle
- `make backup` — `docker exec hermes-dispatcher sqlite3 ...kanban.db .dump > backups/kanban_<ts>.sql`, keeps 7 days (also cron'd on server at 02:00 via `cloud-init.sh`)
- `make update-profiles` — reinstall profiles in running containers

On Windows: Makefile and `scripts/*.sh` are bash — run them under WSL/git-bash, or run the underlying docker commands manually. There is no test/lint step; sanity-check with `docker compose config`.

## Editing skills

- Skill = `SKILL.md` with YAML frontmatter: `name` (must match the folder), `description`, `license`, optional `metadata.hermes.tags` / `related_skills`.
- **Language convention:** README and most `dispatcher`/`qa` skills are in Russian; `coder` skills are mostly English. Match the existing language of the file you edit; keep skill bodies English or Russian consistently.
- Adding a new profile requires touching all of: new `profiles/<name>/` (config.yaml, .env.example, skills/), a service block in `docker-compose.yml`, and the loop in `scripts/init.sh`.

## Kanban conventions (referenced throughout skills)

- Tasks carry `metadata.project`, `assignee` (role name: `orchestrator` / `coder` / `qa`), `chat_id`, and a `type` (`feature` / `bugfix` / `init` / `ui` / `content` / `integration`).
- The loops pick up tasks with status `ready`. Statuses in use are `ready`, `blocked`, `done`, `cancelled` (`/cancel`); the old `coding`/`review`/`qa` intermediate states are gone.
- Orchestration pattern (`orchestrate-task`): parent task (`assignee: orchestrator`, `ready`) is decomposed into component sub-tasks (`metadata.component: true`, `assignee: coder`, `ready`) plus one final PR task (`metadata.pr_creation: true`, `status: blocked`), all linked via `kanban_link`; the PR task is dependency-blocked on the components (`kanban_link --block`) and becomes `ready` once all are `done`. `orchestrate-task` runs once per task and never polls.
- Coder (`execute-task`) executes `component: true` tasks or the `pr_creation: true` task; QA (`execute-qa-task`) runs `review-and-deploy` and ends in `done` (success), `ready` back to coder (needs fixes), or `blocked` (failure).
- PR branch convention: `feature/<task_id>-<sanitized_title>`, shared by all component sub-tasks.
- Project rules are cached in agent memory per git hash (`rules_hash` in metadata, e.g. `project_<name>_rules_<key>` with `metadata.hash`); `--skip_context_files` on the coder is intentional to avoid memory overload — keep it.
