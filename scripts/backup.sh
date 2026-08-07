#!/bin/bash
BACKUP_DIR="./backups"
mkdir -p "$BACKUP_DIR"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="$BACKUP_DIR/kanban_$TIMESTAMP.sql"

echo "💾 Создание бэкапа Kanban..."
docker exec hermes-dispatcher sqlite3 /home/hermes/.hermes/data/kanban.db .dump > "$BACKUP_FILE"

# Удаляем бэкапы старше 7 дней
find "$BACKUP_DIR" -name "kanban_*.sql" -mtime +7 -delete

echo "✅ Бэкап создан: $BACKUP_FILE"