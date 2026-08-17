---
name: project-discover
description: Scans the workspace for projects
---

# Project Discover

## Overview
Scans the `/workspace` directory, finds Git repositories, reads their context files (`.hermes.md`, `AGENTS.md`, `.cursorrules`) and saves the information to agent memory.

## Instructions

1.  **Scanning**:
    - Run `ls /workspace` and get the list of directories.
    - For each directory, check whether it is a Git repository (presence of `.git`).
    - Skip worktrees: directories where `.git` is a file (worktree pointer) instead of a directory (shared repo). Worktrees follow the pattern `<project>-<task_id>`.

2.  **Reading context**:
    - For each repository found, try to read the files in the following priority order:
      1. `.hermes.md`
      2. `AGENTS.md`
      3. `CLAUDE.md`
      4. `.cursorrules`
    - If none are found, create a basic record with the project name and path.

3.  **Extracting information**:
    - From the files read, extract:
      - Technology stack (frameworks, libraries).
      - Development rules (code style, tests, deployment).
      - Environment variables (if mentioned).
    - Also determine validation commands (linters, tests) — they can be extracted from `package.json` or `Makefile`.

4.  **Saving to memory**:
    - Write structured information about each project to agent memory (e.g., in `MEMORY.md` or a separate note).
    - Use the key: `project:<project_name>`.

5.  **Updating**:
    - Call this skill periodically (e.g., once an hour) or on user command (`/project discover`).

## Tools
- `read_file`, `search_files`
- `memory_write`

## Limitations
- Do not modify project files — read only.
- If the project is already in memory, update the information only if it changed (can be checked by the modification date of `AGENTS.md`).
