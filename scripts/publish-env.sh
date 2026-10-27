#!/usr/bin/env bash
# Usage: scripts/publish-env.sh <persona-dir> <PREFIX>
# Upserts every `terraform output` of <persona-dir> into the root .env as <PREFIX>_<OUTPUT_NAME>.
# Other lines are left untouched; values are never printed.
# ENV_FILE overrides the .env location and TF_OUTPUT_JSON replaces `terraform output -json`
# with a file (both used by the tests).
set -euo pipefail

dir="${1:?usage: publish-env.sh <persona-dir> <PREFIX>}"
prefix="${2:?usage: publish-env.sh <persona-dir> <PREFIX>}"
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
env_file="${ENV_FILE:-$root/.env}"

if [ -n "${TF_OUTPUT_JSON:-}" ]; then
  outputs="$(cat "$TF_OUTPUT_JSON")"
else
  outputs="$(terraform -chdir="$dir" output -json)"
fi

[ -f "$env_file" ] || { : > "$env_file"; chmod 600 "$env_file"; }

count=0
for name in $(printf '%s' "$outputs" | jq -r 'keys[]'); do
  key="${prefix}_$(printf '%s' "$name" | tr '[:lower:]' '[:upper:]')"
  value="$(printf '%s' "$outputs" | jq -r --arg n "$name" '.[$n].value | if type == "string" then . else tojson end')"
  case "$value" in
    *$'\n'*) echo "publish-env: value for $key contains a newline; refusing to write" >&2; exit 1 ;;
  esac

  tmp="$(mktemp)"
  found=0
  while IFS= read -r line || [ -n "$line" ]; do
    case "$line" in
      "$key="*) printf '%s=%s\n' "$key" "$value" >> "$tmp"; found=1 ;;
      *) printf '%s\n' "$line" >> "$tmp" ;;
    esac
  done < "$env_file"
  [ "$found" -eq 1 ] || printf '%s=%s\n' "$key" "$value" >> "$tmp"

  if cmp -s "$tmp" "$env_file"; then rm -f "$tmp"; else cat "$tmp" > "$env_file"; rm -f "$tmp"; fi
  count=$((count + 1))
done

echo "publish-env: wrote $count ${prefix}_* keys to $env_file"
