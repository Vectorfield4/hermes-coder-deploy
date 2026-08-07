#!/bin/sh

# Обновление системы
apt -y update
apt -y upgrade

# Установка Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker root

# Установка Git, Make, sqlite3
apt -y install git make sqlite3

# Клонирование репозитория
cd /root
git clone https://github.com/Vectorfield4/hermes-coder-deploy.git
cd hermes-coder-deploy

# Создание .env файлов из шаблонов
make init

# Настройка ежедневного бэкапа Kanban в 02:00
(crontab -l 2>/dev/null | grep -v 'make backup'; echo "0 2 * * * cd /root/hermes-coder-deploy && make backup") | crontab -

echo "=================================================="
echo "✅ Система подготовлена!"
echo ""
echo "Теперь выполните по SSH:"
echo "  1. Заполните секреты в файлах:"
echo "     nano profiles/dispatcher/.env   (TELEGRAM_BOT_TOKEN)"
echo "     nano profiles/coder/.env        (GITHUB_TOKEN, OPENAI_API_KEY, OPENAI_API_BASE)"
echo "     nano profiles/qa/.env           (GITHUB_TOKEN, FTP_HOST, FTP_USER, FTP_PASS, OPENAI_API_KEY, OPENAI_API_BASE)"
echo ""
echo "  2. Запустите контейнеры:"
echo "     cd /root/hermes-coder-deploy && make up"
echo ""
echo "  3. Проверьте логи: make logs"
echo "=================================================="