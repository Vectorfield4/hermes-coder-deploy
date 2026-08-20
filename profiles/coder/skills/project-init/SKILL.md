---
name: project-init
description: "Initializes a new project on the standardized stack (React + Vite + TypeScript + MUI) and links it to Vercel for staging deploys."
license: MIT
metadata:
  hermes:
    tags: [project, init, setup, vercel]
    related_skills: [setup-ci, deploy-vercel]
---

# Project Init

Called by `execute-task` for `type: init` tasks. Clones repo, scaffolds the stack, installs deps, links Vercel, sets up CI.

## Steps

### 1. Clone
- Load retry protocol: `skill_view("project-init", "references/retry.md")`.
- If `/workspace/<project>` missing → `git clone <repo_url> /workspace/<project>`. Apply retry.
- If exists → `git -C /workspace/<project> pull`.

### 2. Write project AGENTS.md
Create `/workspace/<project>/AGENTS.md` listing:
- Stack: React 19 + Vite 7 + TypeScript 5 + MUI 7 + Zustand 5 + TanStack Query 5 + GSAP 3 + Three.js/R3F 9 + Vitest + MSW + Biome 2 + Storybook 9.
- Commands: `npm run dev`, `npm run build`, `npm run test`, `npm run lint`, `npm run format`, `npm run storybook`.
- Applicable skills: `project-init`, `setup-ci`, `ui-architect`, `ui-implementer`, `threejs-scene-builder`, `integration-specialist`, `content-strategist`, `narrative-designer`, `simple-task-executor`, `technical-planner`, `frontend-stack`.
- No Tailwind, no ESLint/Prettier — Biome instead.

### 3. Scaffold (React + Vite + TypeScript)
Create files:
- `index.html` — Vite entry with `<div id="root">` and `/src/main.tsx`.
- `vite.config.ts` — `@vitejs/plugin-react`, test block with `environment: "jsdom"`, `setupFiles: "./src/test/setup.ts"`, `globals: true`.
- `tsconfig.json`, `tsconfig.app.json`, `tsconfig.node.json` — standard Vite + React + TS.
- `biome.json` — Biome config for `ts`/`tsx`/`json` with recommended rules.
- `src/vite-env.d.ts`, `src/main.tsx`, `src/App.tsx` — bootstrap. `main.tsx` mounts inside `BrowserRouter` + `QueryClientProvider`, starts MSW in dev.
- `src/stores/useAppStore.ts` — Zustand store example.
- `src/mocks/handlers.ts`, `src/mocks/browser.ts`, `src/test/setup.ts` — MSW setup.
- `.storybook/main.ts`, `.storybook/preview.tsx` — Storybook for Vite + React.
- `.gitignore` — `node_modules`, `dist`, `.env`, `.env.*`, `.vercel/.env*`.

### 4. Create package.json
- Load the template: `skill_view("project-init", "references/package.json")`.
- Replace `<project_name>` with the actual project name.
- Write to `/workspace/<project>/package.json`.

### 5. Install dependencies
- Load retry protocol. Run `npm install`. Apply retry for network errors.
- Ensure `package-lock.json` is committed (pins exact versions).

### 6. Link to Vercel (staging deploys)
- Requires `VERCEL_TOKEN` in env. If missing → skip with warning, continue.
- If `VERCEL_ORG_ID` + `VERCEL_PROJECT_ID` are set → create `.vercel/project.json` with those values.
- Otherwise → `npx --yes vercel@latest link --yes --token "$VERCEL_TOKEN"`. If it needs interactive input → report back that user must create the Vercel project manually.
- Verify `.vercel/project.json` exists with `orgId` and `projectId`. Safe to commit. Never commit `.vercel/.env*`.

### 7. Commit and push
- Load retry protocol. Commit scaffold (including `.vercel/project.json`) to main branch and push.

### 8. Set up CI
- `skill_run(setup-ci, project)` — creates `.github/workflows/ci.yml`.

### 9. Report
- Return: cloned repo, scaffolded files, deps installed, Vercel link status, CI status.
