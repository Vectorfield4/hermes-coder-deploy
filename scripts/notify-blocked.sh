#!/usr/bin/env bash
# notify-blocked.sh — polls kanban for blocked approval-required tasks,
# sends Telegram notifications to the chat_id owner.
# Runs as a background loop alongside the gateway in the telegram-bot container.

set -uo pipefail

INTERVAL="${NOTIFY_INTERVAL:-30}"              # seconds between polls
REMIND_INTERVAL="${REMIND_INTERVAL:-21600}"    # seconds between reminders (6h)
NOTIFIED_FILE="/tmp/hermes-notified.txt"       # tracks notified task IDs + timestamps
touch "$NOTIFIED_FILE"

# TELEGRAM_BOT_TOKEN is loaded by load-secrets.sh (called before this script)
if [ -z "${TELEGRAM_BOT_TOKEN:-}" ]; then
  echo "[notify-blocked] No Telegram bot token — exiting."
  exit 0
fi

# Build allowed chats lookup (comma-separated list from TELEGRAM_ALLOWED_CHATS)
ALLOWED_CHATS="${TELEGRAM_ALLOWED_CHATS:-}"
is_chat_allowed() {
  local target="$1"
  if [ -z "$ALLOWED_CHATS" ]; then
    return 0  # no restriction
  fi
  local IFS=','
  for ch in $ALLOWED_CHATS; do
    ch=$(echo "$ch" | tr -d ' ')
    if [ "$ch" = "$target" ]; then
      return 0
    fi
  done
  return 1
}

send_telegram() {
  local chat_id="$1"
  local text="$2"
  curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
    -d "chat_id=${chat_id}" \
    -d "text=${text}" \
    -d "parse_mode=Markdown" \
    --max-time 10 >/dev/null 2>&1 || true
}

get_last_notified_time() {
  local task_id="$1"
  grep "^${task_id}|" "$NOTIFIED_FILE" 2>/dev/null | tail -1 | cut -d'|' -f2 || echo "0"
}

update_notified_time() {
  local task_id="$1"
  local now
  now="$(date +%s)"
  # Remove old entry and add new one
  grep -v "^${task_id}|" "$NOTIFIED_FILE" > "${NOTIFIED_FILE}.tmp" 2>/dev/null || true
  echo "${task_id}|${now}" >> "${NOTIFIED_FILE}.tmp"
  mv "${NOTIFIED_FILE}.tmp" "$NOTIFIED_FILE"
}

is_first_notification() {
  local task_id="$1"
  ! grep -q "^${task_id}|" "$NOTIFIED_FILE" 2>/dev/null
}

poll_once() {
  local blocked_json
  blocked_json="$(hermes kanban list --status blocked --json 2>/dev/null)" || blocked_json="[]"

  local task task_id reason chat_id project title pr_url
  while IFS= read -r task; do
    task_id="$(echo "$task" | jq -r '.id')"
    reason="$(echo "$task" | jq -r '.reason')"
    chat_id="$(echo "$task" | jq -r '.metadata.chat_id')"
    project="$(echo "$task" | jq -r '.metadata.project // "unknown"')"
    title="$(echo "$task" | jq -r '.title // "no title"')"

    [ -z "$task_id" ] && continue
    [ -z "$chat_id" ] && continue
    is_chat_allowed "$chat_id" || continue

    # Only notify for approval-required blocks
    if ! echo "$reason" | grep -qi "approval-required"; then
      continue
    fi

    # Extract PR URL from reason if present
    pr_url="$(echo "$reason" | grep -oP 'https://github\.com/\S+' || true)"

    local now last_notified should_notify
    now="$(date +%s)"

    if is_first_notification "$task_id"; then
      should_notify=1
    else
      last_notified="$(get_last_notified_time "$task_id")"
      if [ $(( now - last_notified )) -ge "$REMIND_INTERVAL" ]; then
        should_notify=1
      else
        should_notify=0
      fi
    fi

    [ "$should_notify" -eq 0 ] && continue

    # Build notification message
    local msg="🔔 *Approval required*

Task *#${task_id}* is blocked and waiting for your approval.

*Project:* ${project}
*Title:* ${title}
*Reason:* ${reason}"

    if [ -n "$pr_url" ]; then
      msg="${msg}

🔗 ${pr_url}"
    fi

    msg="${msg}

Run \`/unblock ${task_id}\` to approve."

    send_telegram "$chat_id" "$msg"
    update_notified_time "$task_id"

    if is_first_notification "$task_id"; then
      echo "[notify-blocked] Notified chat ${chat_id} about task ${task_id}"
    else
      echo "[notify-blocked] Reminder sent for task ${task_id}"
    fi
  done < <(echo "$blocked_json" | jq -c '.[]')

  # Prune notified file: remove IDs that are no longer blocked
  if [ -s "$NOTIFIED_FILE" ]; then
    local current_ids tmp
    current_ids="$(echo "$blocked_json" | jq -r '.[].id')"
    tmp="$(mktemp)"
    while IFS= read -r line; do
      local id
      id="$(echo "$line" | cut -d'|' -f1)"
      if echo "$current_ids" | grep -qF "$id"; then
        echo "$line"
      fi
    done < "$NOTIFIED_FILE" > "$tmp"
    mv "$tmp" "$NOTIFIED_FILE"
  fi
}

echo "[notify-blocked] Starting notification loop (interval: ${INTERVAL}s, remind: ${REMIND_INTERVAL}s)"
while true; do
  poll_once
  sleep "$INTERVAL"
done
