# Hermes Coder Deploy

Multi-agent development system built on Hermes Agent, orchestrating work through a Kanban board.

## 🐳 Services

| Service | Profile | Role | Command | Skill |
|---------|---------|------|---------|-------|
| **dispatcher** | dispatcher | `orchestrator` | `hermes kanban work --loop` | `orchestrate-task` |
| **coder** | coder | `developer` | `hermes kanban work --loop --skip_context_files` | `execute-task` |
| **qa** | qa | `qa` | `hermes kanban work --loop` | `execute-qa-task` |
| **telegram-bot** | dispatcher | — | `hermes gateway run --gateway telegram` | `command-handler` |

All services share the `hermes-data` volume (Kanban + agent memory) — it is the only coordination channel.

## 🧠 Skills

Each skill is a Markdown instruction for the agent. Skills live in `profiles/<profile>/skills/<skill-name>/SKILL.md`.

### dispatcher
- **command-handler** — handles the `/task`, `/project add`, `/status`, `/cancel`, `/help` commands from Telegram; creates tasks for the orchestrator (or directly for the coder on `/project add`).
- **orchestrate-task** — decomposes a task into component sub-tasks (UI / content / integration), coordinates a single shared branch `feature/<task_id>-<title>` and a final PR task.

### coder
- **execute-task** — executes a single component sub-task (`component: true`), initializes projects (`type: init`), or aggregates changes and creates a PR (`pr_creation: true`).
- **create-pr** — validation (lint/tests), commit, push of the branch, PR creation.
- **project-init** / **setup-ci** — project initialization (for `type: init` tasks).
- **project-discover** — scans `/workspace`, reads project context (`AGENTS.md`, `.hermes.md`, etc.).
- **frontend-stack** — reference hub for the standardized stack; `references/` has a distilled page per library (React, React Router, Zustand, TypeScript, Vite, MUI, React Hook Form, Zod, TanStack Query, GSAP, Three.js/R3F, Vitest, MSW, Biome, Storybook). Loaded by the component skills via `skill_view` when writing code.
- Specialized: **ui-architect**, **ui-implementer**, **content-strategist**, **integration-specialist**, **technical-planner**, **narrative-designer**, **simple-task-executor**, **threejs-scene-builder**.

### qa
- **execute-qa-task** — runs the review task: invokes `review-and-deploy`, returns the task to the coder (`ready`) when issues are found, or blocks it (`blocked`).
- **review-and-deploy** — checks CI (waits up to 10 min), code review, merge (squash), deploy.
- **resolve-merge-conflict** — automatic conflict resolution via `git merge --strategy-option theirs`.
- **cleanup-branch** — deletes the branch after completion.
- **deploy-ftp** — builds the project and uploads it to FTP.

## 🔄 How loops work

There are no cron schedules anymore. Each worker container runs an infinite loop via `hermes kanban work --profile <p> --role <r> --skill <s> --loop --interval 5` (polls Kanban every 5 seconds), and the Telegram gateway runs as a separate `telegram-bot` service. Service → role → skill wiring lives only in `docker-compose.yml`.

**Task flow:** `/task` in Telegram → `ready` task for the orchestrator → decomposition into sub-tasks → the coder executes components → the PR task creates a PR → QA reviews and deploys → `done`.

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
| **Biome** | Linter + Formatter (replaces ESLint + Prettier) |
| **Storybook** | Component documentation and isolation |

- The stack is set up by the **project-init** and **setup-ci** skills; all coder component skills (ui-architect, ui-implementer, threejs-scene-builder, integration-specialist, content-strategist, narrative-designer, simple-task-executor, technical-planner) target only this stack.
- `project-init` writes an `AGENTS.md` into the project repository describing the stack, the commands, and the list of skills that apply to it.
- AI models are not fixed globally: each profile defines a default model in `config.yaml`, and any skill invocation may specify a specific model.

## 🚀 Deployment

### Option 1: Automatic cloud-init (recommended)

1. In the Timeweb Cloud panel, when creating a server, find the **"Cloud-init"** field (Configuration tab).
2. Copy the contents of `cloud-init.sh` from this repository and paste it into the field.
3. Create the server.
4. Once the server has booted, connect via SSH and fill in the secrets (as shown in the cloud-init message).
5. Start the system with `make up`.
6. Verify it works: `make logs`.

The Kanban backup runs automatically every day at 02:00. Adjust the schedule via `crontab -e` if needed.

## 📦 Updating

The containers install profiles from this GitHub repository on startup. To ship changes:

1. `git pull` on the server (updates the local clone that docker compose reads `.env`/compose/scripts from).
2. `docker compose up -d --force-recreate` — for compose/script changes or a full profile reinstall.
3. `make update-profiles` — sufficient for skill-only changes (no restart).
