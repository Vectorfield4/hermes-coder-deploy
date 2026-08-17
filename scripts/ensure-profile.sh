#!/bin/bash
# Ensures a Hermes profile is installed. Skips if already present.
# Usage: ensure-profile.sh <profile-name> [repo-url]
set -euo pipefail

PROFILE="${1:?Usage: ensure-profile.sh <profile-name> [repo-url]}"
REPO_URL="${2:-https://github.com/Vectorfield4/hermes-coder-deploy}"

if hermes profile list 2>/dev/null | grep -q "$PROFILE"; then
  echo "✅ Profile '$PROFILE' already installed"
else
  echo "📦 Installing profile '$PROFILE' from $REPO_URL ..."
  hermes profile install "$REPO_URL" --alias "$PROFILE"
fi
