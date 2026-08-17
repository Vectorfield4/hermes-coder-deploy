#!/bin/bash
set -euo pipefail

BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ ! -r "secrets/postgres_password" ] || [ -z "$(cat secrets/postgres_password)" ]; then
  echo "❌ secrets/postgres_password is missing or empty. Run 'make init' and fill in the secret first."
  exit 1
fi

# ── Kanban backup ───────────────────────────────────────────────────
# `.dump` without isolation captures inconsistent state under concurrent writes.
# Use `.backup` (page-level safe copy) when available, fall back to file copy + dump.
KANBAN_DB="/home/hermes/.hermes/data/kanban.db"
KANBAN_OUT="$BACKUP_DIR/kanban_$TIMESTAMP.sql"

echo "💾 Creating Kanban backup..."

# Try .backup first (safe under concurrent writes, SQLite ≥3.23.0)
if docker exec hermes-dispatcher sqlite3 "$KANBAN_DB" ".backup '/tmp/kanban_backup.db'" 2>/dev/null; then
  docker exec hermes-dispatcher cat /tmp/kanban_backup.db > "$KANBAN_OUT"
  docker exec hermes-dispatcher rm -f /tmp/kanban_backup.db
  echo "  ✅ Used .backup (consistent snapshot)"
else
  # Fallback: copy file then dump (still safer than raw .dump under writes)
  docker exec hermes-dispatcher cp "$KANBAN_DB" /tmp/kanban_copy.db
  docker exec hermes-dispatcher sqlite3 /tmp/kanban_copy.db .dump > "$KANBAN_OUT"
  docker exec hermes-dispatcher rm -f /tmp/kanban_copy.db
  echo "  ⚠️ Used file copy + .dump (best-effort — .backup unavailable)"
fi

# Validate backup is non-empty SQL
if [ ! -s "$KANBAN_OUT" ]; then
  echo "❌ Kanban backup is empty — possible write contention or DB missing"
  exit 1
fi

# ── Memory backup (PostgreSQL) ──────────────────────────────────────
echo "💾 Creating memory backup (dense-mem PostgreSQL)..."
docker exec -e PGPASSWORD="$(cat secrets/postgres_password)" hermes-memory-db \
  pg_dump -U densemem -d densemem --no-owner \
  > "$BACKUP_DIR/memory_$TIMESTAMP.sql"

if [ ! -s "$BACKUP_DIR/memory_$TIMESTAMP.sql" ]; then
  echo "❌ Memory backup is empty — check PostgreSQL connectivity"
  exit 1
fi

# ── Cleanup (7-day retention) ───────────────────────────────────────
find "$BACKUP_DIR" -name "kanban_*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -name "memory_*.sql" -mtime +7 -delete

echo "✅ Backups created: $BACKUP_DIR/kanban_$TIMESTAMP.sql and $BACKUP_DIR/memory_$TIMESTAMP.sql"
