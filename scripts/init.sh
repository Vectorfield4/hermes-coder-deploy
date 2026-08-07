#!/bin/bash
set -e

echo "📁 Создание директорий..."
mkdir -p data workspace backups

echo "🔐 Создание .env файлов из примеров..."
for profile in dispatcher coder qa; do
    if [ ! -f "profiles/$profile/.env" ]; then
        cp "profiles/$profile/.env.example" "profiles/$profile/.env"
        echo "✅ profiles/$profile/.env создан"
    else
        echo "⏭️  profiles/$profile/.env уже существует"
    fi
done

echo "✅ Инициализация завершена."
echo "📝 Отредактируйте .env файлы в profiles/*/ и запустите: docker compose up -d"