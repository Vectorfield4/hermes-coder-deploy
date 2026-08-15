#!/bin/bash
# Bootstraps the dense-mem memory stack: creates the "hermes-coder" team and
# one profile per worker (dispatcher / coder / qa), then prints the API keys
# to paste into profiles/*/.env as DENSE_MEM_API_KEY.
#
# Prerequisites:
#   - `make init` done and CONTROL_PORTAL_TOKEN / POSTGRES_PASSWORD set in .env
#   - the stack running:  make up  (at least memory-db + dense-mem)
#
# Usage:
#   bash scripts/memory-bootstrap.sh
#
# After pasting the keys, recreate the workers so Hermes re-registers the MCP
# server with the correct credentials:
#   docker compose up -d --force-recreate

set -u

if [ ! -f ".env" ]; then
  echo "❌ Root .env not found. Run 'make init' first."
  exit 1
fi

set -a
. ./.env
set +a

TOKEN="${CONTROL_PORTAL_TOKEN:-}"
if [ -z "$TOKEN" ]; then
  echo "❌ CONTROL_PORTAL_TOKEN is empty in .env"
  exit 1
fi

PORT="${CONTROL_PORTAL_PORT:-8090}"
BASE="http://127.0.0.1:${PORT}/control/api"
AUTH="Authorization: Bearer ${TOKEN}"

echo "⏳ Waiting for the dense-mem control portal on port ${PORT}..."
UP=0
for i in $(seq 1 60); do
  if curl -fsS -H "$AUTH" "$BASE/teams" >/dev/null 2>&1; then
    UP=1
    break
  fi
  sleep 2
done
if [ "$UP" -ne 1 ]; then
  echo "❌ Control portal did not come up. Check 'docker compose ps' and 'docker compose logs dense-mem'."
  exit 1
fi
echo "✅ Control portal is up."

echo "Creating team 'hermes-coder'..."
TEAM_RESPONSE=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" \
  -d '{"name":"hermes-coder"}' "$BASE/teams")
echo "Team response: $TEAM_RESPONSE"
echo ""

TEAM_ID=$(printf '%s' "$TEAM_RESPONSE" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

if [ -z "$TEAM_ID" ]; then
  echo "⚠️  Could not extract the team id (it may already exist). Listing teams:"
  curl -fsS -H "$AUTH" "$BASE/teams"
  echo ""
  echo "➡️  Find the 'hermes-coder' team id above and create the profiles manually:"
  echo "   POST /control/api/teams/<team-id>/profiles  {\"name\":\"<profile>\"}"
  exit 1
fi

for profile in dispatcher coder qa; do
  echo "Creating profile '$profile'..."
  RESPONSE=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"name\":\"$profile\"}" "$BASE/teams/$TEAM_ID/profiles")
  echo "Profile '$profile' response: $RESPONSE"
  echo ""
done

echo "===================================================================="
echo "✅ Done. Copy the API key (api_key / secret field) from each profile"
echo "   response into the matching file as DENSE_MEM_API_KEY:"
echo "     profiles/dispatcher/.env"
echo "     profiles/coder/.env"
echo "     profiles/qa/.env"
echo "   (telegram-bot reuses the dispatcher key.)"
echo "   Then:  docker compose up -d --force-recreate"
echo "===================================================================="
