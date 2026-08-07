---
name: project-init
description: Initializes a new project with basic structure, dependencies, and linting setup.
license: MIT
metadata:
  hermes:
    tags: [project, init, setup]
    related_skills: [worker-loop, setup-ci]
---

# Project Init

## Overview
This skill is called by `worker-loop` to initialize a new project that lacks basic configuration files. It creates `package.json`, installs dependencies, sets up linting, and prepares the project for development.

## When to Use
- Automatically triggered by `worker-loop` when a task with description containing "initialize project" is captured.
- Can also be called manually via `skill_run(project-init, project_name)`.

## Instructions

### 1. Input
- Receive `project_name` (the directory name in `/workspace`).

### 2. Determine Project Type
- Read `/workspace/<project>/AGENTS.md` to extract framework/language information (e.g., "React with Tailwind").
- If not found, try to guess from existing files (e.g., `*.py` -> Python, `*.js` -> Node.js).
- Default to **Node.js + React** if uncertain.

### 3. Generate Base Structure
- For Node.js projects:
  - Create `package.json` with:
    ```json
    {
      "name": "<project_name>",
      "version": "1.0.0",
      "scripts": {
        "start": "react-scripts start",
        "build": "react-scripts build",
        "test": "react-scripts test",
        "lint": "eslint src/**/*.{js,jsx,ts,tsx}",
        "format": "prettier --write src/**/*.{js,jsx,ts,tsx,css,json}"
      },
      "dependencies": {
        "react": "^18.2.0",
        "react-dom": "^18.2.0"
      },
      "devDependencies": {
        "eslint": "^8.0.0",
        "prettier": "^3.0.0"
      }
    }