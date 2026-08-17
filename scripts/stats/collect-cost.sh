#!/bin/bash
# Cost proxy: parse steps/retries from structured outcome tags in task_comments.
# Usage: bash stats/collect-cost.sh <kanban.db>
# Output lines: <steps> <retries> (one per matching comment)
# Exit 0 = data, exit 1 = no data or error.

set -euo pipefail
DB="${1:?Usage: collect-cost.sh <kanban.db>}"

if [ ! -f "$DB" ]; then
  exit 1
fi

if ! sqlite3 "$DB" ".tables" 2>/dev/null | grep -q task_comments; then
  exit 1
fi

BODY=$(sqlite3 "$DB" "
  SELECT c.body
  FROM task_comments c
  WHERE c.body LIKE '%[outcome=success]%'
    AND c.body LIKE '%steps=%'
    AND c.timestamp >= datetime('now', '-1 day')
  LIMIT 50;
" 2>/dev/null || echo "")

if [ -z "$BODY" ]; then
  exit 1
fi

TOTAL_STEPS=0
TOTAL_RETRIES=0
COUNT=0

while IFS= read -r line; do
  s=$(echo "$line" | sed -n 's/.*steps=\([0-9]*\).*/\1/p')
  r=$(echo "$line" | sed -n 's/.*retries=\([0-9]*\).*/\1/p')
  TOTAL_STEPS=$((TOTAL_STEPS + ${s:-0}))
  TOTAL_RETRIES=$((TOTAL_RETRIES + ${r:-0}))
  COUNT=$((COUNT + 1))
done <<< "$BODY"

echo "${COUNT} ${TOTAL_STEPS} ${TOTAL_RETRIES}"
