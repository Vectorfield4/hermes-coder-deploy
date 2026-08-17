#!/bin/bash
# Trajectory checks: coder↔QA iteration count per review task.
# Usage: bash stats/collect-sqlite.sh <kanban.db>
# Output: TSV — id|title|iterations (only tasks with > 1 distinct profile)
# Exit 0 = data, exit 1 = no data or error.

set -euo pipefail
DB="${1:?Usage: collect-sqlite.sh <kanban.db>}"

if [ ! -f "$DB" ]; then
  exit 1
fi

# Check table exists
if ! sqlite3 "$DB" ".tables" 2>/dev/null | grep -q task_runs; then
  exit 1
fi

REVIEW_ITERATIONS=$(sqlite3 "$DB" "
  SELECT
    t.id || '|' || SUBSTR(COALESCE(t.title, 'untitled'), 1, 40) || '|' || COUNT(DISTINCT r.profile)
  FROM tasks t
  JOIN task_runs r ON r.task_id = t.id
  WHERE COALESCE(json_extract(t.metadata, '$.type'), '') = 'review'
  GROUP BY t.id
  HAVING COUNT(DISTINCT r.profile) > 1
  ORDER BY COUNT(DISTINCT r.profile) DESC
  LIMIT 10;
" 2>/dev/null || echo "")

if [ -z "$REVIEW_ITERATIONS" ]; then
  exit 1
fi

echo "$REVIEW_ITERATIONS"
