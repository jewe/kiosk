#!/usr/bin/env bash
# App type "web": Google Chrome (deb, no snap) in kiosk mode with hardening policies.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:web"
require_root

if ! dpkg -l google-chrome-stable 2>/dev/null | grep -q '^ii'; then
    apt_update_once
    apt_install wget gnupg ca-certificates
    tmp="$(mktemp -d)"
    wget -qO "$tmp/chrome.deb" https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb
    apt-get install -y "$tmp/chrome.deb"
    rm -rf "$tmp"
fi
# Chrome adds its own apt repo; updates only happen via `kioskctl update`.

install -d -m 0755 /etc/opt/chrome/policies/managed
apt_install nginx unzip curl   # extensions are served from 127.0.0.1:8090 (apps/web/extensions.sh)
install -m 0644 "${KIOSK_SYS}/apps/web/policies.json" /etc/opt/chrome/policies/managed/kiosk.json

install -m 0644 "${KIOSK_SYS}/apps/web/kiosk-web@.service" /etc/systemd/system/
systemctl daemon-reload
log "installed. Add an app of type 'web' to ${KIOSK_CONFIG} and run: sudo kioskctl apply"
