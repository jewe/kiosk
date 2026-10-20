#!/usr/bin/env bash
# Takes a screenshot and sends it to the configured Telegram chat.
#   send.sh [file] [caption]      without file: a fresh screenshot
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="telegram"
[ -f "${KIOSK_SECRETS}/telegram.env" ] && { set -a; source "${KIOSK_SECRETS}/telegram.env"; set +a; }
token="${TELEGRAM_BOT_TOKEN:-}"; chat="$(cfg '.services.telegram.chat_id')"
[ -n "$token" ] || die "TELEGRAM_BOT_TOKEN missing in ${KIOSK_SECRETS}/telegram.env"
[ -n "$chat" ] || die "services.telegram.chat_id missing"
file="${1:-}"
if [ -z "$file" ]; then
    file="$(mktemp --suffix=.png)"; trap 'rm -f "$file"' EXIT
    "${KIOSK_SYS}/tools/screenshot.sh" "$file" >/dev/null || die "screenshot failed"
fi
caption="${2:-$(hostname) $(date '+%Y-%m-%d %H:%M') | up $(uptime -p | sed 's/^up //') | $(kioskctl status 2>/dev/null | awk '/^  / {printf "%s:%s ", $1, $2}')}"
code="$(curl -sS -m 60 -o /tmp/telegram-reply.json -w '%{http_code}' -F "chat_id=${chat}" -F "caption=${caption:0:1000}" -F "photo=@${file}" \
    "https://api.telegram.org/bot${token}/sendPhoto")" || true
if [ "$code" = 200 ]; then log "screenshot sent to chat $chat"; else warn "telegram failed: HTTP $code $(head -c 200 /tmp/telegram-reply.json 2>/dev/null)"; exit 1; fi
