#!/bin/sh

# Update the system
apt -y update
apt -y upgrade

# Install Docker
curl -fsSL https://get.docker.com | sh
# The stack runs under root's docker group (docker group is root-equivalent).
# Acceptable for a single-purpose VPS; the bigger wins are unattended-upgrades
# below and SSH key auth.
usermod -aG docker root

# Install Git, Make, sqlite3, unattended-upgrades (security auto-patching)
apt -y install git make sqlite3 unattended-upgrades
# Enable unattended security upgrades (non-interactive)
cat > /etc/apt/apt.conf.d/20auto-upgrades <<'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
EOF

# Clone the repository
cd /root
git clone https://github.com/Vectorfield4/hermes-coder-deploy.git
cd hermes-coder-deploy

# Create directories + empty secrets/ placeholders (fill in via SSH, see below)
make init

# Set up a daily Kanban backup at 02:00
(crontab -l 2>/dev/null | grep -v 'make backup'; echo "0 2 * * * cd /root/hermes-coder-deploy && make backup") | crontab -

echo "=================================================="
echo "✅ System is ready!"
echo ""
echo "Next steps via SSH:"
echo "  0. Recommended: SSH key auth only (PasswordAuthentication no in /etc/ssh/sshd_config)."
echo "  1. Fill in the secrets (see secrets/README.md):"
echo "     printf '%s' '<telegram_bot_token>'   > secrets/telegram_bot_token"
echo "     printf '%s' '<github_pat>'           > secrets/github_token"
echo "     printf '%s' '<vercel_token>'         > secrets/vercel_token"
echo "     printf '%s' '<deepseek_api_key>'     > secrets/openai_api_key"
echo "     printf '%s' '<pg_password>'          > secrets/postgres_password"
echo "     printf '%s' '<portal_token>'         > secrets/control_portal_token"
echo "     printf '%s' '<deepseek_api_key>'     > secrets/ai_verifier_api_key"
echo "     (FTP + Vercel org/project optional; dense_mem_* keys are created by memory-bootstrap.sh)"
echo ""
echo "  2. Start the containers:"
echo "     cd /root/hermes-coder-deploy && make up"
echo ""
echo "  3. Create the Dense-Mem profiles and paste their API keys:"
echo "     bash scripts/memory-bootstrap.sh"
echo "     (then printf '%s' '<api_key>' > secrets/dense_mem_{dispatcher,coder,qa})"
echo "     docker compose up -d --force-recreate"
echo ""
echo "  4. Check the logs: make logs"
echo "=================================================="
