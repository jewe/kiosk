#!/usr/bin/env bash
# Sends status + current metrics as JSON to services.monitoring.url (POST, bearer token from secrets).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="heartbeat"
[ "$(cfg '.services.monitoring.enabled' false)" = "true" ] || exit 0
url="$(cfg '.services.monitoring.url')"
[ -n "$url" ] || { warn "services.monitoring.url is empty"; exit 0; }
[ -f "${KIOSK_SECRETS}/monitoring.env" ] && { set -a; source "${KIOSK_SECRETS}/monitoring.env"; set +a; }
device="$(cfg '.device.id')"; [ -n "$device" ] || device="$(hostname)"

body="$(jq -c -n --arg device "$device" \
    --argjson status "$(kioskctl status --json 2>/dev/null || echo '{}')" \
    --argjson metrics "$("${KIOSK_SYS}/monitoring/collect.sh" 2>/dev/null || echo '{}')" \
    '{device:$device, status:$status, metrics:$metrics}')"
code="$(curl -sS -m 20 -o /dev/null -w '%{http_code}' -X POST -H 'Content-Type: application/json' \
    ${MONITORING_TOKEN:+-H "Authorization: Bearer ${MONITORING_TOKEN}"} --data "$body" "$url" 2>&1)" || true
case "$code" in
    2*) ;;
    *) warn "heartbeat to $url failed: $code" ;;
esac
