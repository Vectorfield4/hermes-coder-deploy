---
name: frontend-stack
description: Reference for the standardized frontend stack (React + Vite + TypeScript + MUI + Zustand + TanStack Query + GSAP + R3F + Vitest + MSW + Biome + Storybook). Load the per-library reference when writing UI, state, data, 3D, or test code.
license: MIT
metadata:
  hermes:
    tags: [stack, reference, react, mui, vite, typescript, testing, threejs]
    related_skills: [ui-architect, ui-implementer, simple-task-executor, threejs-scene-builder, integration-specialist]
---

# Frontend Stack

## Overview

Lean reference for the standardized stack installed by `project-init`. Each library has a distilled page under `references/`; load only the page you need via `skill_view("frontend-stack", "references/<file>.md")`.

## Stack map

| Area | Library | Reference |
|---|---|---|
| UI library | React 19 | `references/react.md` |
| Routing | React Router v7 | `references/react-router.md` |
| State | Zustand v5 | `references/zustand.md` |
| Typing | TypeScript 5 | `references/typescript.md` |
| Build | Vite 7 | `references/vite.md` |
| UI components | MUI v7 | `references/mui.md` |
| Forms | React Hook Form v7 | `references/react-hook-form.md` |
| Validation | Zod 4 | `references/zod.md` |
| Data fetching | TanStack Query v5 | `references/tanstack-query.md` |
| Animation | GSAP 3 | `references/gsap.md` |
| 3D | Three.js + React Three Fiber 9 | `references/threejs-r3f.md` |
| Testing | Vitest + Testing Library | `references/vitest.md` |
| API mocking | MSW 2 | `references/msw.md` |
| Lint/format | Biome 2 | `references/biome.md` |
| Component docs | Storybook 9 | `references/storybook.md` |

## When to load

- UI / component tasks → `references/react.md`, `references/mui.md` (plus `references/zustand.md` / `references/tanstack-query.md` when state or data is involved).
- Forms → `references/react-hook-form.md`, `references/zod.md`.
- 3D scenes → `references/threejs-r3f.md`.
- Routing / integration / data → `references/react-router.md`, `references/tanstack-query.md`, `references/zustand.md`.
- Tests → `references/vitest.md`, `references/msw.md`.
- Lint / format fixes → `references/biome.md`.
- Storybook stories → `references/storybook.md`.

## Hard rules (no exceptions)

- No Tailwind, no ESLint/Prettier — styling via MUI `sx`/`styled`, linting/formatting via Biome.
- React 19 functional components with hooks; no class components.
- All data fetching through TanStack Query; no raw `fetch` inside components.
- All shared state through Zustand; avoid prop drilling beyond two levels.
- Every API call has an MSW handler; every component has a Storybook story.
- Strict TypeScript: no `any`, no `// @ts-ignore`.
