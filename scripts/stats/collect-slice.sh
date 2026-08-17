#!/bin/bash
# Per-slice scoring: success rate breakdown by task type.
# Usage: bash stats/collect-slice.sh <kanban.db>
# Output: TSV — task_type|total|done|success_rate
# Exit 0 = data, exit 1 = no data or error.

set -euo pipefail
DB="${1:?Usage: collect-slice.sh <kanban.db>}"

if [ ! -f "$DB" ]; then
  exit 1
fi

if ! sqlite3 "$DB" ".tables" 2>/dev/null | grep -q task_runs; then
  exit 1
fi

PER_SLICE=$(sqlite3 "$DB" "
  SELECT
    COALESCE(json_extract(t.metadata, '$.type'), 'unknown') AS task_type,
    COUNT(*) AS total,
    SUM(CASE WHEN t.status = 'done' THEN 1 ELSE 0 END) AS done,
    ROUND(
      SUM(CASE WHEN t.status = 'done' THEN 1.0 ELSE 0.0 END) * 100 / COUNT(*),
      1
    ) AS success_rate
  FROM tasks t
  GROUP BY task_type
  HAVING total > 0
  ORDER BY total DESC;
" 2>/dev/null || echo "")

if [ -z "$PER_SLICE" ]; then
  exit 1
fi

echo "$PER_SLICE"
