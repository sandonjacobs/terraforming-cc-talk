#!/usr/bin/env bash
# Usage: source scripts/load-env.sh <persona-dir>
# Exports each key listed in <persona-dir>/required-env.txt from the root .env as
# TF_VAR_<lowercased key>. Fails (without printing values) naming every missing or empty key.
# ENV_FILE overrides the .env location (used by the tests).

_load_env_main() {
  local dir="$1"
  local root env_file required missing key value line
  root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
  env_file="${ENV_FILE:-$root/.env}"
  required="$dir/required-env.txt"

  if [ -z "$dir" ] || [ ! -f "$required" ]; then
    echo "load-env: missing required-env.txt in '$dir'" >&2
    return 1
  fi

  missing=""
  while IFS= read -r key || [ -n "$key" ]; do
    case "$key" in ''|'#'*) continue ;; esac
    value=""
    if [ -f "$env_file" ]; then
      line="$(grep -E "^${key}=" "$env_file" | tail -n 1)"
      value="${line#*=}"
    fi
    if [ -z "$value" ]; then
      missing="$missing $key"
    else
      export "TF_VAR_$(printf '%s' "$key" | tr '[:upper:]' '[:lower:]')=$value"
    fi
  done < "$required"

  if [ -n "$missing" ]; then
    echo "load-env: required values missing or empty in $env_file:" >&2
    for key in $missing; do echo "  - $key" >&2; done
    echo "Apply the upstream personas first (see the README)." >&2
    return 1
  fi
}

_load_env_main "${1:-}"
_load_env_rc=$?
unset -f _load_env_main
# Works both when sourced (return) and when executed (exit).
return $_load_env_rc 2>/dev/null || exit $_load_env_rc
