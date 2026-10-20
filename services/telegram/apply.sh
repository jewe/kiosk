#!/usr/bin/env bash
# services.telegram: screenshots to a Telegram chat at boot and every `interval`.
#   services:
#     telegram: {enabled: true, chat_id: "123456", interval: 60m, on_boot: true}
#   token in /opt/kiosk/secrets/telegram.env: TELEGRAM_BOT_TOKEN="..."
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="telegram"
units=/etc/systemd/system
install -m 0644 "${KIOSK_SYS}/services/telegram/kiosk-telegram.service" "$units/"
if [ "$(cfg '.services.telegram.enabled' false)" != "true" ]; then
    systemctl disable --now kiosk-telegram.timer >/dev/null 2>&1 || true
    rm -f "$units/kiosk-telegram.timer"; systemctl daemon-reload; exit 0
fi
[ -n "$(cfg '.services.telegram.chat_id')" ] || { warn "services.telegram.chat_id is empty"; exit 1; }
[ -f "${KIOSK_SECRETS}/telegram.env" ] || warn "no ${KIOSK_SECRETS}/telegram.env (TELEGRAM_BOT_TOKEN)"
interval="$(cfg '.services.telegram.interval' 60m)"
[[ "$interval" =~ ^[0-9]+(s|m|h|min)?$ ]] || { warn "telegram.interval '$interval' invalid, using 60m"; interval=60m; }
boot="2min"; [ "$(cfg '.services.telegram.on_boot' true)" = "false" ] && boot="$interval"
{
    echo "[Unit]"; echo "Description=Kiosk: screenshot to Telegram"
    echo; echo "[Timer]"; echo "OnBootSec=$boot"; echo "OnUnitActiveSec=$interval"; echo "AccuracySec=1min"
    echo; echo "[Install]"; echo "WantedBy=timers.target"
} | write_file "$units/kiosk-telegram.timer" || true
systemctl daemon-reload
systemctl enable --now kiosk-telegram.timer >/dev/null 2>&1
log "screenshot to chat $(cfg '.services.telegram.chat_id') at boot and every $interval"
