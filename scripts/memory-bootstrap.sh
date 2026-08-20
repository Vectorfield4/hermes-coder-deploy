#!/bin/bash
# Bootstraps the dense-mem memory stack: creates the "hermes-coder" team and
# one profile per worker (dispatcher / coder / qa), then saves API keys directly
# into secrets/dense_mem_<profile>.
#
# Prerequisites:
#   - `make init` done and CONTROL_PORTAL_TOKEN set in secrets/control_portal_token
#   - the memory stack running:  docker compose up -d memory-db embedding dense-mem
#
# Usage:
#   bash scripts/memory-bootstrap.sh
#
# Idempotent — safe to run multiple times. Existing teams/profiles are reused.

set -u

if [ ! -r "secrets/control_portal_token" ]; then
  echo "❌ secrets/control_portal_token not readable. Run 'make init' and fill in the secret first."
  exit 1
fi

TOKEN="$(cat secrets/control_portal_token)"
if [ -z "$TOKEN" ]; then
  echo "❌ secrets/control_portal_token is empty"
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

# --- Team ---
TEAM_ID=""

# Try to find existing team
TEAMS_RESPONSE=$(curl -fsS -H "$AUTH" "$BASE/teams" 2>/dev/null || echo "[]")
TEAM_ID=$(printf '%s' "$TEAMS_RESPONSE" | sed -n 's/.*"name"[[:space:]]*:[[:space:]]*"hermes-coder".*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

# Also try reversed JSON key order
if [ -z "$TEAM_ID" ]; then
  TEAM_ID=$(printf '%s' "$TEAMS_RESPONSE" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*"name"[[:space:]]*:[[:space:]]*"hermes-coder".*/\1/p' | head -n1)
fi

if [ -z "$TEAM_ID" ]; then
  echo "Creating team 'hermes-coder'..."
  TEAM_RESPONSE=$(curl -fsS -X POST -H "$AUTH" -H "Content-Type: application/json" \
    -d '{"name":"hermes-coder"}' "$BASE/teams")
  TEAM_ID=$(printf '%s' "$TEAM_RESPONSE" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)
  if [ -z "$TEAM_ID" ]; then
    echo "❌ Could not create or find team 'hermes-coder'."
    echo "   Response: $TEAM_RESPONSE"
    exit 1
  fi
  echo "✅ Team created (id: $TEAM_ID)"
else
  echo "✅ Team 'hermes-coder' exists (id: $TEAM_ID)"
fi

# --- Profiles ---
extract_key() {
  printf '%s' "$1" | sed -n 's/.*"api_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1
}

for profile in dispatcher coder qa; do
  FILE="secrets/dense_mem_${profile}"

  # Try creating the profile
  RESPONSE=$(curl -s -w "\n%{http_code}" -X POST -H "$AUTH" -H "Content-Type: application/json" \
    -d "{\"name\":\"$profile\"}" "$BASE/teams/$TEAM_ID/profiles" 2>/dev/null)
  HTTP_CODE=$(printf '%s' "$RESPONSE" | tail -n1)
  BODY=$(printf '%s' "$RESPONSE" | sed '$d')

  if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
    API_KEY=$(extract_key "$BODY")
    if [ -n "$API_KEY" ]; then
      printf '%s' "$API_KEY" > "$FILE"
      echo "✅ Profile '$profile' created → $FILE"
    else
      echo "⚠️  Profile '$profile' created but could not extract API key."
      echo "   Response: $BODY"
    fi
  elif [ "$HTTP_CODE" = "409" ] || [ "$HTTP_CODE" = "400" ]; then
    # Profile already exists — try to list and extract key
    echo "   Profile '$profile' already exists, fetching key..."
    PROFILES=$(curl -fsS -H "$AUTH" "$BASE/teams/$TEAM_ID/profiles" 2>/dev/null || echo "[]")
    API_KEY=$(printf '%s' "$PROFILES" | sed -n "/\"name\"[[:space:]]*:[[:space:]]*\"$profile\"/{n;p}" | sed -n 's/.*"api_key"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' | head -n1)

    # Fallback: try extracting from the full response with a broader pattern
    if [ -z "$API_KEY" ]; then
      API_KEY=$(printf '%s' "$PROFILES" | tr '\n' ' ' | sed -n "s/.*\"name\"[[:space:]]*:[[:space:]]*\"${profile}\"[^}]*\"api_key\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -n1)
    fi

    if [ -n "$API_KEY" ]; then
      printf '%s' "$API_KEY" > "$FILE"
      echo "✅ Profile '$profile' key saved → $FILE"
    else
      echo "⚠️  Could not extract API key for existing profile '$profile'."
      echo "   Check manually: curl -H 'Authorization: Bearer $TOKEN' $BASE/teams/$TEAM_ID/profiles"
    fi
  else
    echo "❌ Failed to create profile '$profile' (HTTP $HTTP_CODE)"
    echo "   Response: $BODY"
  fi
done

echo ""
echo "===================================================================="
echo "✅ All keys saved to secrets/dense_mem_*"
echo "   Now restart workers to pick up the new credentials:"
echo "     docker compose up -d --force-recreate"
echo "===================================================================="
