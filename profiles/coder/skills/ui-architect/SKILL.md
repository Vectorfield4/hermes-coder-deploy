---
name: ui-architect
description: Designs the page structure and selects components
metadata:
  hermes:
    tags: [ui, design]
    related_skills: [narrative-designer, content-strategist]
---

# UI Architect

Your task is to design the page structure and decide which components to use. Projects run on the standardized stack (React + MUI, see the project `AGENTS.md`).

## Instructions

1. Read `artifacts/narrative.md` and `artifacts/content-plan.md`.

2. Load the stack references via `skill_view` for the design decisions:
   - `references/mui.md` (component vocabulary)
   - `references/react-router.md`, `references/zustand.md`, `references/tanstack-query.md` (architecture)
   - `references/threejs-r3f.md` (3D insertion points)

3. Define the page structure (sections top to bottom):
   - Header — logo, navigation
   - Hero — main block
   - Sections 1, 2, 3... — content blocks
   - Footer

4. For each section choose MUI components:
   - `Container`, `Grid`, `Box` — for layout
   - `Typography` — for text
   - `Button` — for CTAs
   - `Card` — for benefits
   - `TextField`, `Select` — for forms

5. Define the architecture:
   - Routes (React Router)
   - Global state (Zustand)
   - API/data fetching (TanStack Query)

6. Determine where to insert the 3D scene (Three.js / React Three Fiber).

7. Save the result to `artifacts/design-spec.md`.
