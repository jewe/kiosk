#!/usr/bin/env bash
# services.usb_action: udev rule + unit; the action script lives in /opt/kiosk/usb-action.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="usb"
install -m 0644 "${KIOSK_SYS}/services/usb/kiosk-usb-action@.service" /etc/systemd/system/
if [ "$(cfg '.services.usb_action.enabled' false)" = "true" ]; then
    [ -f "${KIOSK_DIR}/usb-action.sh" ] || install -m 0755 "${KIOSK_SYS}/services/usb/usb-action.default.sh" "${KIOSK_DIR}/usb-action.sh"
    install -m 0644 "${KIOSK_SYS}/services/usb/90-kiosk-usb.rules" /etc/udev/rules.d/
    log "usb action enabled: ${KIOSK_DIR}/usb-action.sh"
else
    rm -f /etc/udev/rules.d/90-kiosk-usb.rules
fi
udevadm control --reload >/dev/null 2>&1 || true
systemctl daemon-reload
