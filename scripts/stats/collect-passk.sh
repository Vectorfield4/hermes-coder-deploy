#!/bin/bash
# pass^k metric: consecutive done tasks without a blocked/failed interruption.
# Usage: bash stats/collect-passk.sh <kanban.db>
# Output: <consecutive_done> <total_done> <total_tasks>
# Exit 0 = data, exit 1 = no data or error.

set -euo pipefail
DB="${1:?Usage: collect-passk.sh <kanban.db>}"

if [ ! -f "$DB" ]; then
  exit 1
fi

RESULT=$(sqlite3 "$DB" "
  WITH ranked AS (
    SELECT
      status,
      ROW_NUMBER() OVER (ORDER BY updated_at DESC) AS rn
    FROM tasks
  ),
  streak AS (
    SELECT MIN(rn) AS break_at
    FROM ranked
    WHERE status != 'done'
  )
  SELECT
    (SELECT COALESCE(MIN(break_at) - 1, (SELECT COUNT(*) FROM tasks)) FROM streak) AS consecutive_done,
    (SELECT COUNT(*) FROM tasks WHERE status = 'done') AS total_done,
    (SELECT COUNT(*) FROM tasks) AS total_tasks;
" 2>/dev/null || echo "")

if [ -z "$RESULT" ]; then
  exit 1
fi

echo "$RESULT"
