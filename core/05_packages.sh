#!/usr/bin/env bash
# Base tools used by kioskctl, monitoring and the display stack.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="packages"

apt_install \
    yq jq curl wget ca-certificates gnupg \
    pciutils usbutils lm-sensors lvm2 \
    htop nano less \
    network-manager \
    pipewire pipewire-pulse wireplumber alsa-utils

# NetworkManager handles WLAN later; keep netplan's ethernet config as is.
systemctl enable NetworkManager >/dev/null 2>&1 || true

# pipewire runs as user services of the kiosk user; lingering keeps them alive without a login
loginctl enable-linger "$KIOSK_USER" 2>/dev/null || true
log "done"
