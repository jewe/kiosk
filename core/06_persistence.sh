#!/usr/bin/env bash
# overlayroot + journald. The actual mode comes from kiosk.yaml (persistence.mode)
# and is applied by `kioskctl mount <mode>`. Setup installs the pieces and leaves rw.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="persistence"

apt_install overlayroot
[ -f /etc/overlayroot.conf ] || echo 'overlayroot=""' > /etc/overlayroot.conf

# journald: volatile by default, small, rate-limited. `kioskctl mount data+journal` adds persistence.
write_file /etc/systemd/journald.conf.d/10-kiosk.conf <<'J' && systemctl restart systemd-journald || true
[Journal]
Storage=auto
SystemMaxUse=500M
RuntimeMaxUse=100M
MaxRetentionSec=90day
SyncIntervalSec=5min
RateLimitIntervalSec=30s
RateLimitBurst=1000
J
log "overlayroot installed, mode is '$(grep -o 'overlayroot="[^"]*"' /etc/overlayroot.conf)' until kioskctl mount is used"
