---
name: project-init
description: Initializes a new project on the standardized stack (React + Vite + TypeScript + MUI) and links it to Vercel for staging deploys. Called by execute-task for `type: init` tasks.
license: MIT
metadata:
  hermes:
    tags: [project, init, setup, vercel]
    related_skills: [setup-ci, deploy-vercel]
---

# Project Init

## Overview
This skill is called by `execute-task` to initialize a new project. It clones the repository, scaffolds the **standardized stack** (see README of the deploy repo), installs dependencies, writes the project `AGENTS.md`, links the repo to Vercel (so `deploy-vercel` can deploy it to staging), and prepares the project for development. CI setup is delegated to the `setup-ci` skill.

## When to Use
- Automatically triggered by `execute-task` for tasks with `metadata.type == "init"` (created via the `/project add` command).
- Can also be called manually via `skill_run(project-init, project, repo_url)`.

## Instructions

### 1. Input
- Receive `project` (the directory name in `/workspace`) and `repo_url`.

### 2. Clone the Repository
- If `/workspace/<project>` does not exist or is empty:
  - Run `git clone <repo_url> /workspace/<project>`.
- If it already exists:
  - Pull the latest changes: `git -C /workspace/<project> pull`.

### 3. Write the Project AGENTS.md
Create `/workspace/<project>/AGENTS.md` (in the project language, English by default) listing:
- The standardized stack (see section 5 and the deploy repo README).
- The commands: `npm run dev`, `npm run build`, `npm run test`, `npm run lint`, `npm run format`, `npm run storybook`.
- The Hermes skills that apply to this project: `project-init`, `setup-ci`, `ui-architect`, `ui-implementer`, `threejs-scene-builder`, `integration-specialist`, `content-strategist`, `narrative-designer`, `simple-task-executor`, `technical-planner`, `frontend-stack` (reference hub for the stack's libraries).
- Note: the project targets the standardized stack only (no Tailwind, no ESLint/Prettier — Biome instead).

### 4. Generate the Scaffold (React + Vite + TypeScript)
Create the following files:

- `index.html` — Vite entry with `<div id="root"></div>` and `/src/main.tsx`.
- `vite.config.ts` — `@vitejs/plugin-react`, `test` block with `environment: "jsdom"`, `setupFiles: "./src/test/setup.ts"`, `globals: true`.
- `tsconfig.json` — references `tsconfig.app.json` and `tsconfig.node.json`.
- `tsconfig.app.json` / `tsconfig.node.json` — standard Vite + React + TS config.
- `biome.json` — Biome config for `ts`/`tsx`/`json` with recommended rules (replace ESLint + Prettier).
- `src/vite-env.d.ts`, `src/main.tsx`, `src/App.tsx` — app bootstrap:
  - `main.tsx` mounts the app inside `BrowserRouter` + `QueryClientProvider` and starts MSW in development.
- `src/stores/useAppStore.ts` — Zustand store example.
- `src/mocks/handlers.ts`, `src/mocks/browser.ts`, `src/test/setup.ts` — MSW setup.
- `.storybook/main.ts`, `.storybook/preview.tsx` — Storybook configured for Vite + React.
- `.gitignore` — `node_modules`, `dist`, `.env`, `.env.*`, `.vercel/.env*` (local env files with secrets are ignored; `.vercel/project.json` is committed — see step 7).

### 5. Create package.json with the Pinned Stack
```json
{
  "name": "<project_name>",
  "version": "1.0.0",
  "private": true,
  "type": "module",
  "scripts": {
    "dev": "vite",
    "build": "tsc -b && vite build",
    "preview": "vite preview",
    "test": "vitest run",
    "test:watch": "vitest",
    "lint": "biome check .",
    "format": "biome format --write .",
    "storybook": "storybook dev -p 6006",
    "build-storybook": "storybook build"
  },
  "dependencies": {
    "@emotion/react": "^11",
    "@emotion/styled": "^11",
    "@mui/material": "^7",
    "@react-three/drei": "^10",
    "@react-three/fiber": "^9",
    "@tanstack/react-query": "^5",
    "gsap": "^3",
    "react": "^19",
    "react-dom": "^19",
    "react-hook-form": "^7",
    "react-router-dom": "^7",
    "three": "^0.178.0",
    "zod": "^4",
    "zustand": "^5"
  },
  "devDependencies": {
    "@storybook/react": "^9",
    "@storybook/react-vite": "^9",
    "@testing-library/jest-dom": "^6",
    "@testing-library/react": "^16",
    "@testing-library/user-event": "^14",
    "@types/react": "^19",
    "@types/react-dom": "^19",
    "@vitejs/plugin-react": "^5",
    "biome": "^2",
    "jsdom": "^26",
    "msw": "^2",
    "storybook": "^9",
    "typescript": "^5",
    "vite": "^7",
    "vitest": "^3"
  }
}
```

### 6. Install Dependencies
- Run `npm install` in the project root.
- Ensure `package-lock.json` is generated and committed — it pins exact versions.

### 7. Link the Project to Vercel (for staging deploys)
- Requires `VERCEL_TOKEN` in the coder container environment (injected from `secrets/vercel_token`). If it is missing, skip this step with a warning (the project can be linked later) and continue — the rest of the flow is unaffected.
- In `/workspace/<project>`:
  - **If `VERCEL_ORG_ID` and `VERCEL_PROJECT_ID` are set** in the environment:
    - Create `.vercel/project.json` directly:
      ```json
      {
        "orgId": "<VERCEL_ORG_ID>",
        "projectId": "<VERCEL_PROJECT_ID>"
      }
      ```
    - The Vercel project must already exist in the dashboard (import the repo, or create it with `npx --yes vercel@latest project add <project> --token "$VERCEL_TOKEN"`).
  - **Otherwise** (no IDs in the environment), link by name/remote:
    - `npx --yes vercel@latest link --yes --token "$VERCEL_TOKEN"`.
    - If linking fails or the CLI needs interactive input (project not found), do NOT guess IDs — report back that the user must create the Vercel project and re-run `vercel link`.
- Verify `.vercel/project.json` exists and contains `orgId` and `projectId`.
- This file is safe to commit: it is what `deploy-vercel` (QA profile) reads to deploy this project to staging. Never commit `.vercel/.env*` or `.env.local` (they contain secrets).

### 8. Commit and Push
- Commit the scaffold (including `.vercel/project.json`) to the project's main branch and push.

### 9. Set Up CI
- Call `skill_run(setup-ci, project)` to create and push `.github/workflows/ci.yml` (`npm run lint` / `npm run test` / `npm run build`).

### 10. Report Back
- Return a success summary (cloned repo, scaffolded files, installed dependencies, Vercel link status, CI status).
