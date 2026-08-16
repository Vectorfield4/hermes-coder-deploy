#!/bin/bash
# Daily stats: queries Kanban SQLite + dense-mem PostgreSQL, sends summary to Telegram.
# Usage: TELEGRAM_CHAT_ID=<id> bash scripts/daily-stats.sh
# Or:    bash scripts/daily-stats.sh <chat_id>

set -euo pipefail

CHAT_ID="${1:-${TELEGRAM_CHAT_ID:-}}"
if [ -z "$CHAT_ID" ]; then
  echo "Usage: TELEGRAM_CHAT_ID=<id> bash scripts/daily-stats.sh"
  echo "   or: bash scripts/daily-stats.sh <chat_id>"
  exit 1
fi

if [ ! -r "secrets/telegram_bot_token" ] || [ -z "$(cat secrets/telegram_bot_token)" ]; then
  echo "❌ secrets/telegram_bot_token is missing or empty."
  exit 1
fi

BOT_TOKEN="$(cat secrets/telegram_bot_token)"
DB="hermes-data/data/kanban.db"

if [ ! -f "$DB" ]; then
  echo "❌ Kanban database not found at $DB"
  exit 1
fi

# --- Kanban stats ---
TOTAL_TASKS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
DONE_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND updated_at >= datetime('now', '-1 day');" 2>/dev/null || echo "0")
BLOCKED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='blocked';" 2>/dev/null || echo "0")
READY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='ready';" 2>/dev/null || echo "0")
CANCELLED_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='cancelled' AND updated_at >= datetime('now', '-1 day');" 2>/dev/null || echo "0")

# Completed tasks today (title + assignee)
DONE_LIST=$(sqlite3 "$DB" "SELECT '- ' || COALESCE(title, 'untitled') || ' [' || COALESCE(assignee, '?') || ']' FROM tasks WHERE status='done' AND updated_at >= datetime('now', '-1 day') ORDER BY updated_at DESC LIMIT 10;" 2>/dev/null || echo "")

# Blocked tasks
BLOCKED_LIST=$(sqlite3 "$DB" "SELECT '- ' || COALESCE(title, 'untitled') || ' (' || COALESCE(metadata, '') || ')' FROM tasks WHERE status='blocked' LIMIT 5;" 2>/dev/null || echo "")

# --- Memory stats (best-effort, may fail if password is wrong) ---
MEMORY_RETRACTED=""
if [ -r "secrets/postgres_password" ] && [ -n "$(cat secrets/postgres_password)" ]; then
  PG_PASS="$(cat secrets/postgres_password)"
  MEMORY_TOTAL=$(docker exec -e PGPASSWORD="$PG_PASS" hermes-memory-db psql -U densemem -d densemem -t -c "SELECT COUNT(*) FROM submissions;" 2>/dev/null || echo "?")
  MEMORY_RETRACTED=$(docker exec -e PGPASSWORD="$PG_PASS" hermes-memory-db psql -U densemem -d densemem -t -c "SELECT COUNT(*) FROM submissions WHERE retracted = true;" 2>/dev/null || echo "?")
fi

# --- Format message ---
MSG="📊 *Daily Stats — $(date +%Y-%m-%d)*

📋 *Kanban*
- Total tasks: ${TOTAL_TASKS}
- Done today: ${DONE_TODAY}
- Ready (pending): ${READY}
- Blocked: ${BLOCKED}
- Cancelled today: ${CANCELLED_TODAY}"

if [ -n "$DONE_LIST" ]; then
  MSG="${MSG}

✅ *Completed today*
${DONE_LIST}"
fi

if [ -n "$BLOCKED_LIST" ]; then
  MSG="${MSG}

🚫 *Blocked*
${BLOCKED_LIST}"
fi

if [ -n "$MEMORY_RETRACTED" ] && [ "$MEMORY_RETRACTED" != "?" ]; then
  MSG="${MSG}

🧠 *Memory (E-pool)*
- Total records: ${MEMORY_TOTAL}
- Retracted: ${MEMORY_RETRACTED}"
fi

# --- Send to Telegram ---
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d parse_mode="Markdown" \
  -d text="$MSG" \
  > /dev/null

echo "✅ Daily stats sent to chat $CHAT_ID"
