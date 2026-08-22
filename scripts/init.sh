#!/bin/bash
set -e

echo "📁 Creating directories..."
mkdir -p workspace backups secrets

echo "🔐 Creating empty secret placeholder files in secrets/ (never overwrites existing)..."
for name in \
  token \
  telegram_allowed_chats \
  github_token \
  vercel_token \
  vercel_org_id \
  ftp_host \
  ftp_user \
  ftp_pass \
  openai_api_key_dispatcher \
  openai_api_key_coder \
  openai_api_key_qa \
  openai_api_key_telegram \
  openai_api_base_dispatcher \
  openai_api_base_coder \
  openai_api_base_qa \
  openai_api_base_telegram \
  dense_mem_dispatcher \
  dense_mem_coder \
  dense_mem_qa \
  postgres_password \
  control_portal_token \
  ai_verifier_api_key \
  ai_verifier_api_url \
  ai_verifier_model; do
  if [ ! -f "secrets/$name" ]; then
    : > "secrets/$name"
  fi
done
chmod 600 secrets/*

if [ ! -f "secrets/README.md" ]; then
  cat > "secrets/README.md" <<'EOF'
# secrets/

All secrets live here as plain files, one value per file (no comments inside —
the whole file content IS the value, trailing newline is stripped).

Map (see docker-compose.yml `secrets:`):

| File                      | Required | Used by            | Value                                  |
|---------------------------|----------|--------------------|----------------------------------------|
| token                       | yes      | telegram-bot       | Telegram bot token                   |
| telegram_allowed_chats     | yes      | telegram-bot, daily-stats | Comma-separated allowed chat IDs |
| github_token              | yes      | coder, qa          | GitHub PAT                              |
| vercel_token              | yes      | coder, qa          | Vercel API token                        |
| vercel_org_id             | optional | coder, qa          | Vercel org id (team scope pin for `vercel link`) |
| ftp_host / ftp_user / ftp_pass | yes (prod FTP) | qa        | FTP credentials for `/deploy`          |
| openai_api_key_dispatcher | yes      | dispatcher         | LLM API key (OpenAI-compatible)        |
| openai_api_key_coder      | yes      | coder              | LLM API key (OpenAI-compatible)        |
| openai_api_key_qa         | yes      | qa                 | LLM API key (OpenAI-compatible)        |
| openai_api_key_telegram   | yes      | telegram-bot       | LLM API key (OpenAI-compatible)        |
| openai_api_base_dispatcher| yes      | dispatcher         | LLM base URL (OpenAI-compatible)       |
| openai_api_base_coder     | yes      | coder              | LLM base URL                            |
| openai_api_base_qa        | yes      | qa                 | LLM base URL                            |
| openai_api_base_telegram  | yes      | telegram-bot       | LLM base URL                            |
| dense_mem_dispatcher      | yes      | dispatcher, telegram-bot | dense-mem profile key, created by `bash scripts/memory-bootstrap.sh` |
| dense_mem_coder           | yes      | coder              | same                                   |
| dense_mem_qa              | yes      | qa                 | same                                   |
| postgres_password         | yes      | memory-db, dense-mem | PostgreSQL password                 |
| control_portal_token      | yes      | dense-mem, memory-bootstrap.sh | dense-mem control portal token |
| ai_verifier_api_key       | yes      | dense-mem          | LLM API key (fact verification)        |
| ai_verifier_api_url       | yes      | dense-mem          | LLM base URL (fact verification)       |
| ai_verifier_model         | yes      | dense-mem          | LLM model id (fact verification)       |

Fill each file with `printf '%s' '<value>' > secrets/<name>`. Compose mounts
them into `/run/secrets/<name>`; `scripts/load-secrets.sh` (inside the
containers) maps `VAR_FILE` back to `VAR`.
EOF
  echo "✅ secrets/README.md created"
fi

echo "✅ Initialization complete."
echo "📝 Fill in the files in secrets/ (see secrets/README.md), then run: docker compose up -d"
