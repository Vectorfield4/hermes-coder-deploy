#!/bin/sh
# load-secrets.sh — Docker `_FILE` convention loader.
#
# For every env var named <NAME>_FILE it reads the file at <NAME>_FILE and
# exports <NAME> with the file's contents (trailing newline stripped). This is
# how compose secrets (mounted under /run/secrets) reach applications that only
# read env vars (Hermes, dense-mem, ...).
#
# Used inside containers:
#   - Hermes workers:  sh -c ". /usr/local/bin/load-secrets.sh && hermes ..."
#   - dense-mem:       entrypoint wrapper (docker-compose.yml)
#
# Fail-fast: a referenced but unreadable/missing file aborts the container so a
# misconfigured secret never silently degrades the system.

set -u

for var in $(env | sed -n 's/^\([A-Z][A-Z0-9_]*\)_FILE=.*/\1/p' | sort -u); do
  eval "path=\${${var}_FILE}"
  [ -n "$path" ] || continue
  if [ ! -r "$path" ]; then
    echo "load-secrets: ${var}_FILE=$path is not readable" >&2
    exit 1
  fi
  export "$var=$(cat "$path")"
  unset "${var}_FILE"
done

return 0 2>/dev/null || true
