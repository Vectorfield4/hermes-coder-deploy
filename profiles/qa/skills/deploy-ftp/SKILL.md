---
name: deploy-ftp
description: Pulls the latest main branch, builds the project, and uploads the build to an FTP host.
license: MIT
metadata:
  hermes:
    tags: [qa, deploy, ftp]
    related_skills: [execute-qa-task]
---

# Deploy FTP

## Overview
Runs the production FTP deploy for the current `main` branch. Called by `execute-qa-task` for `type: deploy` tasks (triggered by the `/deploy` Telegram command).

## When to Use
- Manually via `/deploy` in Telegram.
- **Do not use** this skill from the review flow — merged PRs deploy to Vercel staging instead (see `deploy-vercel`).

## Instructions

1. Make sure the repository is up to date: `git checkout main && git pull origin main`.
2. If a build is required, run the commands from `validation_commands` (e.g., `npm install && npm run build`).
3. Get FTP credentials from the environment: `FTP_HOST`, `FTP_USER`, `FTP_PASS` (injected from `secrets/ftp_host`, `secrets/ftp_user`, `secrets/ftp_pass`).
4. Load retry protocol: `skill_view("deploy-ftp", "references/retry.md")`.
5. Upload the files to FTP:
   - Use `lftp` or `curl`.
   - Example: `lftp -u $FTP_USER,$FTP_PASS $FTP_HOST -e "mirror -R ./build ./public; quit"`.
   - Apply the retry protocol — transient errors (timeout, network, 5xx) are retried with exponential backoff; permanent errors (auth, 404) fail immediately.
6. On success — return SUCCESS.
7. On failure — return an error to move the task to `blocked`.
