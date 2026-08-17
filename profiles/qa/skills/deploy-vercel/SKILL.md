---
name: deploy-vercel
description: Builds the current dev branch and creates a staging (preview) deployment on Vercel using the Vercel CLI.
license: MIT
metadata:
  hermes:
    tags: [qa, deploy, vercel]
    related_skills: [review-and-merge, deploy-ftp]
---

# Deploy to Vercel (Staging)

## Overview
Builds the project at `dev` and uploads it to Vercel as a staging/preview deployment. Called by `review-and-merge` after a PR is merged to `dev`.

## When to Use
- Automatically after `review-and-merge` merges a PR to `dev`.
- **Do not use** this skill manually.

## Prerequisites
- The project is linked to Vercel and the link is committed in the repo at `/workspace/<project>/.vercel/project.json` (contains `orgId` + `projectId`).
- `VERCEL_TOKEN` available in the QA container environment (injected from `secrets/vercel_token`, shared by all projects).
- Node.js/npm is available (required for `npx vercel`).
- This skill operates in the QA worktree at `/workspace/<project>-<task_id>`.

## Linking a project (one-time setup per project)
- In the project repo, run once:
  - `npx --yes vercel@latest link --yes --token "$VERCEL_TOKEN"`.
- This creates `.vercel/project.json` with `orgId` and `projectId` — **commit it** so the QA container can deploy it.

## Instructions

### 1. Sync `dev`
- Navigate to the worktree: `cd /workspace/<project>-{{ env.HERMES_KANBAN_TASK }}`.
- Load retry protocol: `skill_view("deploy-vercel", "references/retry.md")`.
- `git checkout dev && git pull origin dev`. Apply retry protocol to the pull — transient errors are retried; permanent errors fail immediately.

### 2. Resolve the Vercel link for this project
- Read `/workspace/<project>/.vercel/project.json` → extract `orgId` and `projectId`.
- Fallback (backward compatibility): if the file is missing, use `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` from the QA container environment (injected from `secrets/vercel_org_id` / `secrets/vercel_project_id`).
- If neither exists → return an error: "Vercel is not linked for project <project>". Do not guess.

### 3. Pull Vercel project settings
- `npx --yes vercel@latest pull --yes --environment=preview --token "$VERCEL_TOKEN"`.
- The committed `.vercel/project.json` (or the env fallback) selects the correct project non-interactively.

### 4. Build locally
- `npx --yes vercel@latest build --token "$VERCEL_TOKEN"`.
- On failure — return an error (do not deploy).

### 5. Deploy (staging)
- Load retry protocol: `skill_view("deploy-vercel", "references/retry.md")`.
- `npx --yes vercel@latest deploy --prebuilt --token "$VERCEL_TOKEN"`. Apply retry protocol — transient errors (timeout, 5xx) are retried; build failures and auth errors fail immediately.
- If the CLI supports it, append `--wait` to block until the deployment is ready.
- As a fallback, poll the returned deployment URL until it responds with HTTP 200 (max 5 minutes).

### 6. Output
- Return the staging URL (e.g., `https://<deployment>.vercel.app`) to `review-and-merge`.

## Common Pitfalls
- **Not being on `dev`**: always checkout and pull `dev` first so the merge is included.
- **Non-interactive mode**: always pass `--token` and `--yes`; the CLI must never prompt.
- **Project not linked**: if `.vercel/project.json` is missing and there is no env fallback, return an error instead of guessing — run `vercel link` in the project first.
- **Committing secrets**: `.vercel/project.json` only contains `orgId`/`projectId` (not secrets) and is safe to commit; `.vercel/.env*.local` and `.vercel/.env*.prod.local` files must never be committed.

## Verification Checklist
- [ ] `dev` is up to date.
- [ ] Vercel link resolved for `<project>` (`.vercel/project.json` or env fallback).
- [ ] Project settings pulled successfully.
- [ ] Local build succeeds.
- [ ] Deployment URL returned and reachable.
