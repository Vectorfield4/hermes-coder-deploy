#!/bin/bash
# Daily stats orchestrator: collects metrics from helpers, sends Telegram summary.
# Usage: TELEGRAM_CHAT_ID=<id> bash scripts/daily-stats.sh
# Or:    bash scripts/daily-stats.sh <chat_id>
#
# Helpers live in scripts/stats/:
#   collect-trajectory.sh — #1 coder↔QA iteration count
#   collect-cost.sh       — #2 steps/retries from outcome tags
#   collect-drift.sh      — #3 TSR drift detection
#   collect-slice.sh      — #4 per-type success rate
#   collect-passk.sh      — #8 consecutive done streak
#   collect-task-tokens.sh       — #11 per-task token cost (branch join)
#   collect-task-percentiles.sh  — #11 per-turn token percentiles

set -euo pipefail

CHAT_ID="${1:-${TELEGRAM_CHAT_ID:-}}"
if [ -z "$CHAT_ID" ]; then
  echo "Usage: TELEGRAM_CHAT_ID=<id> bash scripts/daily-stats.sh"
  echo "   or: bash scripts/daily-stats.sh <chat_id>"
  exit 1
fi

if [ ! -r "secrets/token" ] || [ -z "$(cat secrets/token)" ]; then
  echo "❌ secrets/token is missing or empty."
  exit 1
fi

BOT_TOKEN="$(cat secrets/token)"

# Validate chat_id against allowed list
if [ -r "secrets/telegram_allowed_chats" ]; then
  ALLOWED=$(cat secrets/telegram_allowed_chats)
  if [ -n "$ALLOWED" ]; then
    MATCHED=0
    IFS=',' read -ra CHATS <<< "$ALLOWED"
    for ch in "${CHATS[@]}"; do
      ch=$(echo "$ch" | tr -d ' ')
      if [ "$ch" = "$CHAT_ID" ]; then
        MATCHED=1
        break
      fi
    done
    if [ "$MATCHED" -eq 0 ]; then
      echo "❌ Chat $CHAT_ID is not in TELEGRAM_ALLOWED_CHATS."
      exit 1
    fi
  fi
fi
DB="hermes-data/data/kanban.db"
STATE_DB="hermes-data/state.db"
STATS_DIR="$(dirname "$0")/stats"
TSR_HISTORY="hermes-data/tsr_history.csv"

if [ ! -f "$DB" ]; then
  echo "❌ Kanban database not found at $DB"
  exit 1
fi

mkdir -p "$(dirname "$TSR_HISTORY")"
touch "$TSR_HISTORY"

TODAY=$(date +%Y-%m-%d)

# ── Basic Kanban stats ──────────────────────────────────────────────
TOTAL_TASKS=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks;" 2>/dev/null || echo "0")
DONE_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='done' AND updated_at >= datetime('now', '-1 day');" 2>/dev/null || echo "0")
BLOCKED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='blocked';" 2>/dev/null || echo "0")
READY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='ready';" 2>/dev/null || echo "0")
CANCELLED_TODAY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='cancelled' AND updated_at >= datetime('now', '-1 day');" 2>/dev/null || echo "0")

DONE_LIST=$(sqlite3 "$DB" "SELECT '- ' || COALESCE(title, 'untitled') || ' [' || COALESCE(assignee, '?') || ']' FROM tasks WHERE status='done' AND updated_at >= datetime('now', '-1 day') ORDER BY updated_at DESC LIMIT 10;" 2>/dev/null || echo "")

BLOCKED_LIST=$(sqlite3 "$DB" "SELECT '- ' || COALESCE(title, 'untitled') || ' (' || COALESCE(metadata, '') || ')' FROM tasks WHERE status='blocked' LIMIT 5;" 2>/dev/null || echo "")

# ── Memory stats (best-effort) ──────────────────────────────────────
MEMORY_TOTAL=""
MEMORY_RETRACTED=""
if [ -r "secrets/postgres_password" ] && [ -n "$(cat secrets/postgres_password)" ]; then
  PG_PASS="$(cat secrets/postgres_password)"
  # Use .pgpass file instead of PGPASSWORD env to avoid password in ps aux
  docker exec hermes-memory-db sh -c "printf '*:5432:densemem:densemem:%s\n' '$PG_PASS' > /tmp/.pgpass"
  MEMORY_TOTAL=$(docker exec -e PGPASSFILE=/tmp/.pgpass hermes-memory-db psql -U densemem -d densemem -t -c "SELECT COUNT(*) FROM submissions;" 2>/dev/null || echo "?")
  MEMORY_RETRACTED=$(docker exec -e PGPASSFILE=/tmp/.pgpass hermes-memory-db psql -U densemem -d densemem -t -c "SELECT COUNT(*) FROM submissions WHERE retracted = true;" 2>/dev/null || echo "?")
  docker exec hermes-memory-db rm -f /tmp/.pgpass
fi

# ── #1 Trajectory checks ───────────────────────────────────────────
TRAJ_OUT=""
TRAJ_WARNINGS=""
if TRAJ_OUT=$("$STATS_DIR/collect-trajectory.sh" "$DB" 2>/dev/null); then
  while IFS='|' read -r _tid ttitle iterations; do
    if [ "${iterations:-0}" -gt 3 ]; then
      TRAJ_WARNINGS="${TRAJ_WARNINGS}
⚠️ ${ttitle} — ${iterations} coder↔QA rounds (threshold: 3)"
    fi
  done <<< "$TRAJ_OUT"
fi

# ── #2 Cost proxy ──────────────────────────────────────────────────
COST_COUNT=0; COST_STEPS=0; COST_RETRIES=0
if COST_LINE=$("$STATS_DIR/collect-cost.sh" "$DB" 2>/dev/null); then
  read -r COST_COUNT COST_STEPS COST_RETRIES <<< "$COST_LINE"
fi

# ── #3 Drift detection ────────────────────────────────────────────
DRIFT_TODAY="0"; DRIFT_AVG="0"; DRIFT_PCT="0"; DRIFT_ALERT="0"
if DRIFT_LINE=$("$STATS_DIR/collect-drift.sh" "$DONE_TODAY" "$TOTAL_TASKS" "$TSR_HISTORY" 2>/dev/null); then
  read -r DRIFT_TODAY DRIFT_AVG DRIFT_PCT DRIFT_ALERT <<< "$DRIFT_LINE"
fi

# ── #4 Per-slice scoring ──────────────────────────────────────────
PER_SLICE=""
PER_SLICE=$("$STATS_DIR/collect-slice.sh" "$DB" 2>/dev/null || echo "")

# ── #8 pass^k: consecutive done streak ────────────────────────────
PASSK_CONSECUTIVE=0; PASSK_DONE=0; PASSK_TOTAL=0
if PASSK_LINE=$("$STATS_DIR/collect-passk.sh" "$DB" 2>/dev/null); then
  read -r PASSK_CONSECUTIVE PASSK_DONE PASSK_TOTAL <<< "$PASSK_LINE"
fi

# ── #9 Prioritization metrics ─────────────────────────────────────
PRIO_SCORED=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='ready' AND metadata LIKE '%priority_score%';" 2>/dev/null || echo "0")
PRIO_READY=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE status='ready';" 2>/dev/null || echo "0")

# ── #10 Exploration metrics ───────────────────────────────────────
EXPLORATION_COUNT=$(sqlite3 "$DB" "SELECT COUNT(*) FROM tasks WHERE metadata LIKE '%exploration_triggered: true%' OR metadata LIKE '%exploration_flag: true%';" 2>/dev/null || echo "0")
HIGH_ITERATION=$(sqlite3 "$DB" "SELECT '- ' || COALESCE(title, 'untitled') FROM tasks WHERE metadata LIKE '%review_iterations%' AND CAST(SUBSTR(metadata, INSTR(metadata, 'review_iterations:') + 19) AS INTEGER) >= 3 AND status != 'done' LIMIT 5;" 2>/dev/null || echo "")

# ── #11 Per-task token cost (branch join) ──────────────────────────
TASK_TOKENS=""
TASK_PERCENTILES=""
if [ -f "$STATE_DB" ]; then
  TASK_TOKENS=$("$STATS_DIR/collect-task-tokens.sh" "$DB" "$STATE_DB" 2>/dev/null || echo "")
  TASK_PERCENTILES=$("$STATS_DIR/collect-task-percentiles.sh" "$STATE_DB" 2>/dev/null || echo "")
fi

# ── Build message ──────────────────────────────────────────────────
MSG="📊 *Daily Stats — ${TODAY}*

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

if [ -n "$TRAJ_OUT" ]; then
  MSG="${MSG}

🔄 *Review Iterations (coder↔QA)*"
  while IFS='|' read -r _tid ttitle iterations; do
    MSG="${MSG}
- ${ttitle}: ${iterations} rounds"
  done <<< "$TRAJ_OUT"
fi

if [ -n "$TRAJ_WARNINGS" ]; then
  MSG="${MSG}${TRAJ_WARNINGS}"
fi

if [ "${COST_COUNT:-0}" -gt 0 ]; then
  AVG_STEPS=$(awk "BEGIN {printf \"%.1f\", $COST_STEPS / $COST_COUNT}")
  MSG="${MSG}

💰 *Cost Proxy (today)*
- Tasks with outcome data: ${COST_COUNT}
- Total steps (skill_run): ${COST_STEPS} (avg ${AVG_STEPS}/task)
- Total retries: ${COST_RETRIES}"
fi

if [ "$DRIFT_AVG" != "0" ] && [ "$DRIFT_AVG" != "0.0" ]; then
  MSG="${MSG}

📈 *TSR Drift*
- Today: ${DRIFT_TODAY}%
- 7-day avg: ${DRIFT_AVG}%"
fi

if [ "$DRIFT_ALERT" = "1" ]; then
  MSG="${MSG}

📉 *DRIFT ALERT:* TSR dropped ${DRIFT_PCT}% (today ${DRIFT_TODAY}% vs 7d avg ${DRIFT_AVG}%)"
fi

if [ -n "$PER_SLICE" ]; then
  MSG="${MSG}

📊 *Per-Type Breakdown*"
  while IFS='|' read -r task_type total done_count success_rate; do
    MSG="${MSG}
- ${task_type}: ${done_count}/${total} done (${success_rate}%)"
  done <<< "$PER_SLICE"
fi

if [ "${PASSK_CONSECUTIVE:-0}" -gt 0 ]; then
  MSG="${MSG}

🎯 *pass^k*
- Consecutive done: ${PASSK_CONSECUTIVE}
- Total done: ${PASSK_DONE}/${PASSK_TOTAL}"
fi

if [ "${PRIO_SCORED:-0}" -gt 0 ]; then
  MSG="${MSG}

⚡ *Prioritization*
- Scored ready tasks: ${PRIO_SCORED}/${PRIO_READY}"
fi

if [ "${EXPLORATION_COUNT:-0}" -gt 0 ]; then
  MSG="${MSG}

🔍 *Exploration triggers*: ${EXPLORATION_COUNT}"
fi

if [ -n "$HIGH_ITERATION" ]; then
  MSG="${MSG}

🔄 *High-iteration tasks (≥3 rounds)*
${HIGH_ITERATION}"
fi

# ── #11 Per-task token cost ────────────────────────────────────────
if [ -n "$TASK_TOKENS" ]; then
  TOTAL_COST_ALL=0
  TOTAL_IN_ALL=0
  TOTAL_OUT_ALL=0

  # Aggregate totals and build per-model summary
  declare -A MODEL_IN MODEL_OUT MODEL_COST MODEL_TURNS
  TOP_TASKS=""

  while IFS='|' read -r tid ttitle tmodel ttin ttout tcost; do
    TOTAL_COST_ALL=$(awk "BEGIN {printf \"%.4f\", $TOTAL_COST_ALL + $tcost}")
    TOTAL_IN_ALL=$((TOTAL_IN_ALL + ttin))
    TOTAL_OUT_ALL=$((TOTAL_OUT_ALL + ttout))

    # Per-model aggregation
    MODEL_IN[$tmodel]=$(( ${MODEL_IN[$tmodel]:-0} + ttin ))
    MODEL_OUT[$tmodel]=$(( ${MODEL_OUT[$tmodel]:-0} + ttout ))
    MODEL_COST[$tmodel]=$(awk "BEGIN {printf \"%.4f\", ${MODEL_COST[$tmodel]:-0} + $tcost}")

    # Top tasks (first 5 unique by task_id)
    if [ $(echo "$TOP_TASKS" | grep -c "^${tid}|" 2>/dev/null || echo "0") -eq 0 ]; then
      TOP_TASKS="${TOP_TASKS}
${tid}|${ttitle}|${tmodel}|${ttin}|${ttout}|${tcost}"
    fi
  done <<< "$TASK_TOKENS"

  # Build message: top tasks
  TOP_LIST=""
  SHOWN=0
  while IFS='|' read -r tid ttitle tmodel ttin ttout tcost; do
    [ -z "$tid" ] && continue
    [ "$SHOWN" -ge 5 ] && break
    # Truncate title for Telegram
    SHORT_TITLE=$(echo "$ttitle" | cut -c1-30)
    TOP_LIST="${TOP_LIST}
- ${SHORT_TITLE} [${tmodel}]: ~$((ttin / 1000))K in / ~$((ttout / 1000))K out (\$${tcost})"
    SHOWN=$((SHOWN + 1))
  done <<< "$TOP_TASKS"

  # Build message: per-model breakdown
  MODEL_LIST=""
  for model in "${!MODEL_IN[@]}"; do
    MODEL_LIST="${MODEL_LIST}
- ${model}: ~$(( ${MODEL_IN[$model]} / 1000 ))K in / ~$(( ${MODEL_OUT[$model]} / 1000 ))K out (\$${MODEL_COST[$model]})"
  done

  MSG="${MSG}

💸 *Per-Task Token Cost (24h)*
Top tasks by cost:${TOP_LIST}

Per-model:${MODEL_LIST}

Total: ~$(( (TOTAL_IN_ALL + TOTAL_OUT_ALL) / 1000 ))K tokens | \$${TOTAL_COST_ALL}"
fi

if [ -n "$TASK_PERCENTILES" ]; then
  PCTL_LIST=""
  while IFS='|' read -r model turns avg_in p50 p90 p95 tin tout; do
    [ -z "$model" ] && continue
    PCTL_LIST="${PCTL_LIST}
- ${model}: P50=~$((p50 / 1000))K P90=~$((p90 / 1000))K P95=~$((p95 / 1000))K (${turns} turns)"
  done <<< "$TASK_PERCENTILES"

  if [ -n "$PCTL_LIST" ]; then
    MSG="${MSG}

📈 *Turn Percentiles (per-model)*${PCTL_LIST}"
  fi
fi

# ── Send ───────────────────────────────────────────────────────────
curl -s -X POST "https://api.telegram.org/bot${BOT_TOKEN}/sendMessage" \
  -d chat_id="$CHAT_ID" \
  -d parse_mode="Markdown" \
  -d text="$MSG" \
  > /dev/null

echo "✅ Daily stats sent to chat $CHAT_ID"
