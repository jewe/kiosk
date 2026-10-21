#!/usr/bin/env bash
# Sends the dynamic status + current metrics as JSON to services.monitoring.url (POST, bearer token from secrets).
# The static status (os, config, versions) is included once a day or when it changed.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="heartbeat"
[ "$(cfg '.services.monitoring.enabled' false)" = "true" ] || exit 0
url="$(cfg '.services.monitoring.url')"
[ -n "$url" ] || { warn "services.monitoring.url is empty"; exit 0; }
[ -f "${KIOSK_SECRETS}/monitoring.env" ] && { set -a; source "${KIOSK_SECRETS}/monitoring.env"; set +a; }
device="$(cfg '.device.id')"; [ -n "$device" ] || device="$(hostname)"

static_file="${KIOSK_STATE}/heartbeat-static.json"
static_arg='null'
static_now="$(kioskctl status --json --static 2>/dev/null | jq -c 'del(.ts)' || echo '{}')"
if [ ! -f "$static_file" ] || [ "$(cat "$static_file" 2>/dev/null)" != "$static_now" ] \
   || [ "$(( $(date +%s) - $(stat -c %Y "$static_file") ))" -gt 86400 ]; then
    static_arg="$static_now"
fi
body="$(jq -c -n --arg device "$device" \
    --argjson status "$(kioskctl status --json --dynamic 2>/dev/null || echo '{}')" \
    --argjson metrics "$("${KIOSK_SYS}/monitoring/collect.sh" 2>/dev/null || echo '{}')" \
    --argjson static "$static_arg" \
    '{device:$device, status:$status, metrics:$metrics} + (if $static then {static:$static} else {} end)')"
code="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    ${MONITORING_TOKEN:+-H "Authorization: Bearer ${MONITORING_TOKEN}"} --data "$body" "$url" 2>&1)" || true
case "$code" in
    2*) [ "$static_arg" != null ] && { mkdir -p "$KIOSK_STATE"; printf '%s' "$static_now" > "$static_file"; } ;;
    *) warn "heartbeat to $url failed: $code" ;;
esac
