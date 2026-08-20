#!/bin/bash
# Per-turn token percentiles by model for kanban worker sessions.
# Usage: bash stats/collect-task-percentiles.sh <state.db>
# Output TSV: model|turns|avg_in|p50_in|p90_in|p95_in|total_in|total_out
# Exit 0 = data, exit 1 = no data or error.

set -euo pipefail
STATE_DB="${1:?Usage: collect-task-percentiles.sh <state.db>}"

if [ ! -f "$STATE_DB" ]; then
  exit 1
fi

if ! sqlite3 "$STATE_DB" ".tables" 2>/dev/null | grep -q messages; then
  exit 1
fi

RESULT=$(sqlite3 "$STATE_DB" "
  WITH turns AS (
    SELECT
      s.model,
      m.input_tokens AS in_tok,
      m.output_tokens AS out_tok
    FROM messages m
    JOIN sessions s ON s.id = m.session_id
    WHERE s.source = 'kanban'
      AND s.started_at >= strftime('%s', 'now', '-1 day')
      AND m.role = 'assistant'
      AND m.input_tokens > 0
  ),
  ranked AS (
    SELECT
      model,
      in_tok,
      out_tok,
      percent_rank() OVER (PARTITION BY model ORDER BY in_tok) AS pr
    FROM turns
  )
  SELECT
    model,
    COUNT(*) AS turns,
    ROUND(AVG(in_tok)) AS avg_in,
    MAX(CASE WHEN pr <= 0.50 THEN in_tok END) AS p50_in,
    MAX(CASE WHEN pr <= 0.90 THEN in_tok END) AS p90_in,
    MAX(CASE WHEN pr <= 0.95 THEN in_tok END) AS p95_in,
    SUM(in_tok) AS total_in,
    SUM(out_tok) AS total_out
  FROM ranked
  GROUP BY model
  ORDER BY total_in DESC;
" 2>/dev/null || echo "")

if [ -z "$RESULT" ]; then
  exit 1
fi

echo "$RESULT"
