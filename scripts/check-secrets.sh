#!/bin/bash
# check-secrets.sh — preflight for compose secrets.
#
# Verifies before `docker compose up` that every secret file declared in
# docker-compose.yml exists, and that every *required* secret is non-empty
# (optional ones may stay empty: ftp_*, vercel_org_id, vercel_project_id).
# This makes a fresh clone fail fast instead of silently starting containers
# with empty credentials.

set -u

# Required secrets (see secrets/README.md). Add new required secrets here.
REQUIRED="token TELEGRAM_ALLOWED_CHATS github_token vercel_token openai_api_key \
dense_mem_dispatcher dense_mem_coder dense_mem_qa \
postgres_password control_portal_token ai_verifier_api_key"

if [ ! -f "docker-compose.yml" ]; then
  echo "❌ docker-compose.yml not found. Run this from the repo root."
  exit 1
fi

# Every file declared in the top-level compose `secrets:` map
DECLARED=$(sed -n 's#.*file: \./secrets/\([a-zA-Z0-9_]*\).*#\1#p' docker-compose.yml)

MISSING=()
for name in $DECLARED; do
  [ -f "secrets/$name" ] || MISSING+=("$name")
done

EMPTY=()
for name in $REQUIRED; do
  if [ -f "secrets/$name" ] && [ ! -s "secrets/$name" ]; then
    EMPTY+=("$name")
  fi
done

FAILED=0
if [ "${#MISSING[@]}" -gt 0 ]; then
  FAILED=1
  echo "❌ Missing secret files (run 'make init' or create them):"
  printf '   - secrets/%s\n' "${MISSING[@]}"
fi
if [ "${#EMPTY[@]}" -gt 0 ]; then
  FAILED=1
  echo "❌ Required secret files are empty (fill with printf '%s' '<value>' > secrets/<name>):"
  printf '   - secrets/%s\n' "${EMPTY[@]}"
fi

if [ "$FAILED" -eq 1 ]; then
  echo "See secrets/README.md for the full list. Refusing to start."
  exit 1
fi

echo "✅ Secrets OK: all files present, required ones non-empty."
