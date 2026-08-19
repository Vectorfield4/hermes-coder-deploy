---
name: ui-architect
description: Designs page structure using Atomic Design methodology
metadata:
  hermes:
    tags: [organism, template, page, layout, responsive, b2b, marketing, landing]
    related_skills: [narrative-designer, content-strategist, ui-implementer]
---

# UI Architect

Your task is to design the page architecture using Atomic Design levels. Projects run on the standardized stack (React + MUI, see the project `AGENTS.md`).

## Instructions

1. Read `artifacts/narrative.md` and `artifacts/content-plan.md`.

2. Load the stack references via `skill_view`:
   - `references/mui.md` (component vocabulary)
   - `references/react-router.md`, `references/zustand.md`, `references/tanstack-query.md` (architecture)

3. Define the page using Atomic Design levels:

   **Template** — the page skeleton:
   - Section ordering (which organisms go where)
   - Responsive grid strategy (breakpoints, spacing system)
   - Navigation structure (header organism, footer organism)

   **Organisms** — complex, self-contained sections:
   - Hero organism (primary value prop + CTA molecule + optional 3D scene)
   - Feature organisms (technology/solution blocks with icon atoms)
   - Social proof organism (testimonials, metrics, case studies)
   - Lead capture organism (form molecule + trust signals)

   **Molecules** — reusable composites:
   - CTA button molecule (button atom + icon atom + text atom)
   - Feature card molecule (icon atom + heading atom + description atom)
   - Form field molecule (label atom + input atom + validation atom)

   **Atoms** — smallest units:
   - Button, Typography, Icon, Divider, Badge

4. For each organism, specify:
   - What molecules/atoms it contains
   - Its responsive behavior (mobile/tablet/desktop)
   - Its animation behavior (scroll-triggered, static, interactive)
   - Where 3D scenes or GSAP animations are inserted

5. Define the architecture:
   - Routes (React Router)
   - Global state (Zustand) — what state each organism reads/writes
   - Data fetching (TanStack Query) — which organisms need server data

6. Save the result to `artifacts/design-spec.md`.
