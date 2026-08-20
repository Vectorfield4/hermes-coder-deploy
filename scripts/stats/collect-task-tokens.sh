#!/bin/bash
# Per-task token cost: join kanban task_runs with state.db sessions via branch.
# Usage: bash stats/collect-task-tokens.sh <kanban.db> <state.db>
# Output TSV: task_id|title|model|tokens_in|tokens_out|cost_usd
# Exit 0 = data, exit 1 = no data or error.

set -euo pipefail
KANBAN_DB="${1:?Usage: collect-task-tokens.sh <kanban.db> <state.db>}"
STATE_DB="${2:?Usage: collect-task-tokens.sh <kanban.db> <state.db>}"

if [ ! -f "$KANBAN_DB" ] || [ ! -f "$STATE_DB" ]; then
  exit 1
fi

if ! sqlite3 "$KANBAN_DB" ".tables" 2>/dev/null | grep -q task_runs; then
  exit 1
fi

if ! sqlite3 "$STATE_DB" ".tables" 2>/dev/null | grep -q sessions; then
  exit 1
fi

RESULT=$(sqlite3 "$KANBAN_DB" "
  ATTACH DATABASE '$STATE_DB' AS st;

  SELECT
    t.id AS task_id,
    t.title,
    s.model,
    SUM(s.input_tokens) AS tokens_in,
    SUM(s.output_tokens) AS tokens_out,
    ROUND(SUM(COALESCE(s.estimated_cost_usd, 0)), 4) AS cost_usd
  FROM tasks t
  JOIN task_runs tr ON tr.task_id = t.id
  JOIN st.sessions s
    ON s.git_branch = t.branch_name
    AND s.source = 'kanban'
    AND s.started_at >= tr.started_at
    AND s.started_at <= COALESCE(tr.ended_at, strftime('%s', 'now'))
  WHERE t.branch_name IS NOT NULL
    AND tr.status = 'done'
    AND tr.started_at >= strftime('%s', 'now', '-1 day')
  GROUP BY t.id, t.title, s.model
  ORDER BY cost_usd DESC
  LIMIT 20;
" 2>/dev/null || echo "")

if [ -z "$RESULT" ]; then
  exit 1
fi

echo "$RESULT"
