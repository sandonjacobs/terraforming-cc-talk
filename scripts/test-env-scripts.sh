#!/usr/bin/env bash
# Offline tests for load-env.sh, publish-env.sh and unpublish-env.sh. Uses temp files only.
set -u

SCRIPTS="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

PASS=0
FAIL=0

ok() { PASS=$((PASS + 1)); echo "ok   - $1"; }
bad() { FAIL=$((FAIL + 1)); echo "FAIL - $1"; }

check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@"; then ok "$desc"; else bad "$desc"; fi
}

new_env() { # new_env <content>  -> sets ENV_FILE to a fresh file
  export ENV_FILE="$TMP/.env"
  printf '%s' "$1" > "$ENV_FILE"
}

persona_dir() {
  PDIR="$TMP/persona"
  rm -rf "$PDIR"; mkdir -p "$PDIR"
  printf '%s\n' "# comment" "OMAR_ENVIRONMENT_ID" "OMAR_IDA_KAFKA_API_KEY" > "$PDIR/required-env.txt"
}

# ---------- load-env.sh ----------

persona_dir
new_env $'# header\nOMAR_ENVIRONMENT_ID=env-123\nOMAR_IDA_KAFKA_API_KEY=key-abc\nOMAR_DAN_KAFKA_API_KEY=other-secret\n'
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR" && echo "$TF_VAR_omar_environment_id|$TF_VAR_omar_ida_kafka_api_key|${TF_VAR_omar_dan_kafka_api_key:-unset}") 2>&1)"
check "load exports required keys as lowercase TF_VAR_ and skips unrequired keys" \
  test "$out" = "env-123|key-abc|unset"

persona_dir
new_env $'OMAR_ENVIRONMENT_ID=env-123\nOMAR_IDA_KAFKA_API_KEY=\n'
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR") 2>&1)"; rc=$?
check "load fails on an empty required key" test "$rc" -ne 0
check "load names the empty key" bash -c "[[ \"\$1\" == *OMAR_IDA_KAFKA_API_KEY* ]]" _ "$out"

persona_dir
new_env $'OMAR_ENVIRONMENT_ID=env-123\n'
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR") 2>&1)"; rc=$?
check "load fails on a missing required key" test "$rc" -ne 0
check "load names the missing key" bash -c "[[ \"\$1\" == *OMAR_IDA_KAFKA_API_KEY* ]]" _ "$out"

persona_dir
new_env ''
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR") 2>&1)"; rc=$?
check "load names every missing key at once" \
  bash -c "[[ \"\$1\" == *OMAR_ENVIRONMENT_ID* && \"\$1\" == *OMAR_IDA_KAFKA_API_KEY* ]]" _ "$out"

persona_dir
rm -f "$TMP/.env"; export ENV_FILE="$TMP/.env"
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR") 2>&1)"; rc=$?
check "load fails when .env does not exist" test "$rc" -ne 0

persona_dir
new_env $'OMAR_ENVIRONMENT_ID=env-123\nOMAR_IDA_KAFKA_API_KEY=key-abc\n'
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR") 2>&1)"
check "load does not print secret values" bash -c "[[ \"\$1\" != *key-abc* ]]" _ "$out"

persona_dir
new_env $'OMAR_ENVIRONMENT_ID=env-123\nOMAR_IDA_KAFKA_API_KEY=a=b==c\n'
out="$( (source "$SCRIPTS/load-env.sh" "$PDIR" && echo "$TF_VAR_omar_ida_kafka_api_key") 2>&1)"
check "load keeps equals signs inside values" test "$out" = "a=b==c"

# ---------- publish-env.sh ----------

cat > "$TMP/outputs.json" <<'EOF'
{
  "events_topic": {"sensitive": false, "type": "string", "value": "app-events"},
  "secret_thing": {"sensitive": true, "type": "string", "value": "s3cr3t"}
}
EOF
export TF_OUTPUT_JSON="$TMP/outputs.json"

new_env $'OMAR_ENVIRONMENT_ID=env-123\nALI_EVENTS_TOPIC=old\n'
out="$("$SCRIPTS/publish-env.sh" "$TMP" ALI 2>&1)"
check "publish upserts existing key in place" grep -qx 'ALI_EVENTS_TOPIC=app-events' "$ENV_FILE"
check "publish appends new key with persona prefix" grep -qx 'ALI_SECRET_THING=s3cr3t' "$ENV_FILE"
check "publish leaves other personas' lines untouched" grep -qx 'OMAR_ENVIRONMENT_ID=env-123' "$ENV_FILE"
check "publish does not print secret values" bash -c "[[ \"\$1\" != *s3cr3t* ]]" _ "$out"

before="$(cat "$ENV_FILE")"
"$SCRIPTS/publish-env.sh" "$TMP" ALI >/dev/null 2>&1
check "republishing unchanged outputs leaves the file byte-identical" test "$before" = "$(cat "$ENV_FILE")"

rm -f "$ENV_FILE"
"$SCRIPTS/publish-env.sh" "$TMP" ALI >/dev/null 2>&1
check "publish creates .env when absent" grep -qx 'ALI_EVENTS_TOPIC=app-events' "$ENV_FILE"

cat > "$TMP/outputs.json" <<'EOF'
{"multi": {"sensitive": false, "type": "string", "value": "line1\nline2"}}
EOF
new_env $'OMAR_ENVIRONMENT_ID=env-123\n'
"$SCRIPTS/publish-env.sh" "$TMP" ALI >/dev/null 2>&1; rc=$?
check "publish rejects values containing newlines" test "$rc" -ne 0
unset TF_OUTPUT_JSON

# ---------- unpublish-env.sh ----------

new_env $'OMAR_ENVIRONMENT_ID=env-123\nOMAR_ALI_KAFKA_API_KEY=k\nALI_EVENTS_TOPIC=app-events\nALI_OTHER=x\nDAN_CURATED_TOPICS=t\n'
"$SCRIPTS/unpublish-env.sh" ALI >/dev/null 2>&1
check "unpublish removes only the prefixed lines" \
  bash -c "! grep -q '^ALI_' \"\$1\" && grep -qx 'OMAR_ALI_KAFKA_API_KEY=k' \"\$1\" && grep -qx 'DAN_CURATED_TOPICS=t' \"\$1\" && grep -qx 'OMAR_ENVIRONMENT_ID=env-123' \"\$1\"" _ "$ENV_FILE"

rm -f "$ENV_FILE"
"$SCRIPTS/unpublish-env.sh" ALI >/dev/null 2>&1
check "unpublish succeeds when .env is absent" test "$?" -eq 0

echo
echo "passed: $PASS, failed: $FAIL"
[ "$FAIL" -eq 0 ]
