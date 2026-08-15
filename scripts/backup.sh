#!/bin/bash
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

if [ ! -r "secrets/postgres_password" ] || [ -z "$(cat secrets/postgres_password)" ]; then
  echo "❌ secrets/postgres_password is missing or empty. Run 'make init' and fill in the secret first."
  exit 1
fi

echo "💾 Creating Kanban backup..."
docker exec hermes-dispatcher sqlite3 /home/hermes/.hermes/data/kanban.db .dump > "$BACKUP_DIR/kanban_$TIMESTAMP.sql"

echo "💾 Creating memory backup (dense-mem PostgreSQL)..."
docker exec -e PGPASSWORD="$(cat secrets/postgres_password)" hermes-memory-db \
  pg_dump -U densemem -d densemem --no-owner \
  > "$BACKUP_DIR/memory_$TIMESTAMP.sql"

# Delete backups older than 7 days
find "$BACKUP_DIR" -name "kanban_*.sql" -mtime +7 -delete
find "$BACKUP_DIR" -name "memory_*.sql" -mtime +7 -delete

echo "✅ Backups created: $BACKUP_DIR/kanban_$TIMESTAMP.sql and $BACKUP_DIR/memory_$TIMESTAMP.sql"
