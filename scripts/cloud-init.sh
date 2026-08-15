#!/bin/sh

# Update the system
apt -y update
apt -y upgrade

# Install Docker
curl -fsSL https://get.docker.com | sh
usermod -aG docker root

# Install Git, Make, sqlite3
apt -y install git make sqlite3

# Clone the repository
cd /root
git clone https://github.com/Vectorfield4/hermes-coder-deploy.git
cd hermes-coder-deploy

# Create .env files from templates
make init

# Set up a daily Kanban backup at 02:00
(crontab -l 2>/dev/null | grep -v 'make backup'; echo "0 2 * * * cd /root/hermes-coder-deploy && make backup") | crontab -

echo "=================================================="
echo "✅ System is ready!"
echo ""
echo "Next steps via SSH:"
echo "  1. Fill in the secrets in these files:"
echo "     nano .env                        (POSTGRES_PASSWORD, CONTROL_PORTAL_TOKEN, AI_VERIFIER_API_KEY)"
echo "     nano profiles/dispatcher/.env    (TELEGRAM_BOT_TOKEN)"
echo "     nano profiles/coder/.env         (GITHUB_TOKEN, VERCEL_TOKEN, OPENAI_API_KEY, OPENAI_API_BASE)"
echo "     nano profiles/qa/.env            (GITHUB_TOKEN, FTP_HOST, FTP_USER, FTP_PASS, VERCEL_TOKEN, OPENAI_API_KEY, OPENAI_API_BASE)"
echo ""
echo "  2. Start the containers:"
echo "     cd /root/hermes-coder-deploy && make up"
echo ""
echo "  3. Create the Dense-Mem profiles and paste their API keys:"
echo "     bash scripts/memory-bootstrap.sh"
echo "     (then set DENSE_MEM_API_KEY in profiles/{dispatcher,coder,qa}/.env)"
echo "     docker compose up -d --force-recreate"
echo ""
echo "  4. Check the logs: make logs"
echo "=================================================="
