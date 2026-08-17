#!/bin/bash
# Drift detection: persist daily TSR, compare 7-day rolling average.
# Usage: bash stats/collect-drift.sh <done_today> <total_tasks> <tsr_history_path>
# Output: <tsr_today> <avg_7d> <drift_pct> <alert_triggered>
#   alert_triggered = 1 if drift > 10%, 0 otherwise
# Exit 0 always (drift is best-effort).

set -euo pipefail
DONE_TODAY="${1:?Usage: collect-drift.sh <done_today> <total_tasks> <tsr_history_path>}"
TOTAL_TASKS="${2:?}"
TSR_HISTORY="${3:?}"

if [ "$TOTAL_TASKS" -gt 0 ]; then
  TSR_TODAY=$(awk "BEGIN {printf \"%.2f\", $DONE_TODAY * 100 / $TOTAL_TASKS}")
else
  TSR_TODAY="0.00"
fi

TODAY=$(date +%Y-%m-%d)

# Append today (dedup)
if ! grep -q "^${TODAY}," "$TSR_HISTORY" 2>/dev/null; then
  echo "${TODAY},${TSR_TODAY}" >> "$TSR_HISTORY"
fi

# Trim to 30 days
CUTOFF=$(date -d "-30 days" +%Y-%m-%d 2>/dev/null || date -v-30d +%Y-%m-%d 2>/dev/null || echo "")
if [ -n "$CUTOFF" ] && [ -s "$TSR_HISTORY" ]; then
  awk -F',' -v cutoff="$CUTOFF" '$1 >= cutoff' "$TSR_HISTORY" > "${TSR_HISTORY}.tmp" 2>/dev/null
  mv "${TSR_HISTORY}.tmp" "$TSR_HISTORY" 2>/dev/null || true
fi

AVG_7D="0"
DRIFT_PCT="0"
ALERT="0"

if [ -s "$TSR_HISTORY" ]; then
  AVG_7D=$(tail -7 "$TSR_HISTORY" | awk -F',' '{sum+=$2; n++} END {if(n>0) printf "%.1f", sum/n; else print "0"}')
  if [ "$AVG_7D" != "0" ] && [ "$AVG_7D" != "0.0" ]; then
    DRIFT_PCT=$(awk "BEGIN {printf \"%.1f\", ($AVG_7D - $TSR_TODAY) / $AVG_7D * 100}")
    EXCEEDED=$(awk "BEGIN {print ($DRIFT_PCT > 10) ? 1 : 0}")
    ALERT="$EXCEEDED"
  fi
fi

echo "${TSR_TODAY} ${AVG_7D} ${DRIFT_PCT} ${ALERT}"
