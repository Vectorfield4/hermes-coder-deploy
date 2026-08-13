#!/bin/bash
set -e

echo "📁 Creating directories..."
mkdir -p data workspace backups

echo "🔐 Creating .env files from examples..."
for profile in dispatcher coder qa; do
    if [ ! -f "profiles/$profile/.env" ]; then
        cp "profiles/$profile/.env.example" "profiles/$profile/.env"
        echo "✅ profiles/$profile/.env created"
    else
        echo "⏭️  profiles/$profile/.env already exists"
    fi
done

echo "✅ Initialization complete."
echo "📝 Edit the .env files in profiles/*/ and run: docker compose up -d"
