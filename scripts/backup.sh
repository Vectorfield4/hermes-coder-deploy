#!/bin/bash
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/kanban_$TIMESTAMP.sql"

echo "💾 Creating Kanban backup..."
docker exec hermes-dispatcher sqlite3 /home/hermes/.hermes/data/kanban.db .dump > "$BACKUP_FILE"

# Delete backups older than 7 days
find "$BACKUP_DIR" -name "kanban_*.sql" -mtime +7 -delete

echo "✅ Backup created: $BACKUP_FILE"
