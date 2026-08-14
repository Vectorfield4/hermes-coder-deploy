---
name: deploy-vercel
description: Builds the current main branch and creates a staging (preview) deployment on Vercel using the Vercel CLI.
license: MIT
metadata:
  hermes:
    tags: [qa, deploy, vercel]
    related_skills: [review-and-deploy, deploy-ftp]
---

# Deploy to Vercel (Staging)

## Overview
Builds the project at `main` and uploads it to Vercel as a staging/preview deployment. Called by `review-and-deploy` after a PR is merged to `main`.

## When to Use
- Automatically after `review-and-deploy` merges a PR to `main`.
- **Do not use** this skill manually.

## Prerequisites
- The project is linked to Vercel and the link is committed in the repo at `/workspace/<project>/.vercel/project.json` (contains `orgId` + `projectId`).
- `VERCEL_TOKEN` set in the QA profile `.env` (shared by all projects).
- Node.js/npm is available (required for `npx vercel`).

## Linking a project (one-time setup per project)
- In the project repo, run once:
  - `npx --yes vercel@latest link --yes --token "$VERCEL_TOKEN"`.
- This creates `.vercel/project.json` with `orgId` and `projectId` — **commit it** so the QA container can deploy it.

## Instructions

### 1. Sync `main`
- `cd /workspace/<project>`.
- `git checkout main && git pull origin main`.

### 2. Resolve the Vercel link for this project
- Read `/workspace/<project>/.vercel/project.json` → extract `orgId` and `projectId`.
- Fallback (backward compatibility): if the file is missing, use `VERCEL_ORG_ID` / `VERCEL_PROJECT_ID` from the QA profile `.env`.
- If neither exists → return an error: "Vercel is not linked for project <project>". Do not guess.

### 3. Pull Vercel project settings
- `npx --yes vercel@latest pull --yes --environment=preview --token "$VERCEL_TOKEN"`.
- The committed `.vercel/project.json` (or the env fallback) selects the correct project non-interactively.

### 4. Build locally
- `npx --yes vercel@latest build --token "$VERCEL_TOKEN"`.
- On failure — return an error (do not deploy).

### 5. Deploy (staging)
- `npx --yes vercel@latest deploy --prebuilt --token "$VERCEL_TOKEN"`.
- If the CLI supports it, append `--wait` to block until the deployment is ready.
- As a fallback, poll the returned deployment URL until it responds with HTTP 200 (max 5 minutes).

### 6. Output
- Return the staging URL (e.g., `https://<deployment>.vercel.app`) to `review-and-deploy`.

## Common Pitfalls
- **Not being on `main`**: always checkout and pull `main` first so the merge is included.
- **Non-interactive mode**: always pass `--token` and `--yes`; the CLI must never prompt.
- **Project not linked**: if `.vercel/project.json` is missing and there is no env fallback, return an error instead of guessing — run `vercel link` in the project first.
- **Committing secrets**: `.vercel/project.json` only contains `orgId`/`projectId` (not secrets) and is safe to commit; `.vercel/.env*.local` and `.vercel/.env*.prod.local` files must never be committed.

## Verification Checklist
- [ ] `main` is up to date.
- [ ] Vercel link resolved for `<project>` (`.vercel/project.json` or env fallback).
- [ ] Project settings pulled successfully.
- [ ] Local build succeeds.
- [ ] Deployment URL returned and reachable.
