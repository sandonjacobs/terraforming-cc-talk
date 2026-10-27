#!/usr/bin/env bash
# Usage: scripts/unpublish-env.sh <PREFIX>
# Removes every <PREFIX>_* line from the root .env. ENV_FILE overrides the location (tests).
set -euo pipefail

prefix="${1:?usage: unpublish-env.sh <PREFIX>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${ENV_FILE:-$root/.env}"

if [ ! -f "$env_file" ]; then
  echo "unpublish-env: no $env_file, nothing to remove"
  exit 0
fi

tmp="$(mktemp)"
grep -v "^${prefix}_" "$env_file" > "$tmp" || true
cat "$tmp" > "$env_file"
rm -f "$tmp"
echo "unpublish-env: removed ${prefix}_* keys from $env_file"
