#!/usr/bin/env bash
# Hardware watchdog through systemd (no effect when the board has none).
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="watchdog"

write_file /etc/systemd/system.conf.d/10-kiosk-watchdog.conf <<'W' || true
[Manager]
RuntimeWatchdogSec=60
RebootWatchdogSec=5min
DefaultTimeoutStopSec=20s
W
systemctl daemon-reexec
log "done"
