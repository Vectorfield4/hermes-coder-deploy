---
name: setup-ci
description: Creates a basic CI pipeline (GitHub Actions) for a project on the standardized stack (React + Vite + TypeScript).
metadata:
  hermes:
    tags: [ci, github-actions]
    related_skills: [project-init]
---

# Setup CI

Run once during repository initialization. The project is built on the standardized stack: React + Vite + TypeScript + MUI (see the deploy repo README).

## Algorithm

1. Create `.github/workflows/ci.yml`:
   - Trigger: `push` and `pull_request` on the default branch (`main`/`master`).
   - Steps:
     1. `checkout`
     2. `setup-node` (Node 20, npm cache)
     3. `npm ci`
     4. `npm run lint` (Biome)
     5. `npm run test` (Vitest)
     6. `npm run build` (tsc + vite build)
2. Commit and push the file.
3. Add a task comment: "CI configured".
