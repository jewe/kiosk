#!/usr/bin/env bash
# Called by `kioskctl apply` when a static app was removed from the config. Keeps the content.
set -euo pipefail
name="${1:?name}"
systemctl disable "kiosk-content-update@${name}.service" >/dev/null 2>&1 || true
systemctl disable --now "kiosk-content-update@${name}.timer" >/dev/null 2>&1 || true
rm -rf "/etc/systemd/system/kiosk-content-update@${name}.timer.d"
rm -f "/etc/nginx/sites-enabled/kiosk-${name}.conf" "/etc/nginx/sites-available/kiosk-${name}.conf"
nginx -t >/dev/null 2>&1 && systemctl reload nginx || true
