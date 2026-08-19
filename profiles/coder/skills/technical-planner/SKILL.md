---
name: technical-planner
description: Breaks work down into subtasks and delegates to subagents
metadata:
  hermes:
    tags: [planning, architecture, decomposition]
---

# Technical Planner

Your task is to break the work into isolated subtasks and delegate them to subagents. Projects run on the standardized stack (React + MUI + Three.js/R3F, see the project `AGENTS.md`).

## Instructions

1. Read all artifacts:
   - `artifacts/narrative.md`
   - `artifacts/content-plan.md`
   - `artifacts/design-spec.md`

2. Create an implementation plan in `artifacts/implementation-plan.md`:

   ```markdown
   # Implementation Plan

   ## Task 1: Page layout (MUI)
   - Description: Build all sections according to the design spec
   - Executor: ui-implementer
   - Model: deepseek/deepseek-chat

   ## Task 2: Three.js scene
   - Description: Create a 3D scene from the narrative (React Three Fiber)
   - Executor: threejs-scene-builder
   - Model: deepseek/deepseek-chat

   ## Task 3: Integration
   - Description: Assemble everything into the application (routes, providers)
   - Executor: integration-specialist
   - Model: deepseek/deepseek-chat
   ```

3. For each task call `delegate_task` with a `model` parameter (the model is set per task, not globally).
