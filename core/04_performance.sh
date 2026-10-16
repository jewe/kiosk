#!/usr/bin/env bash
# CPU governor, no sleep, low swappiness, basic sysctl.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="performance"

systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null 2>&1 || true

write_file /etc/systemd/system/kiosk-cpufreq.service <<'UNIT' || true
[Unit]
Description=Kiosk: CPU frequency governor = performance
After=multi-user.target

[Service]
Type=oneshot
ExecStart=/bin/sh -c 'for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$f" ] && echo performance > "$f"; done; exit 0'

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable kiosk-cpufreq.service >/dev/null

write_file /etc/sysctl.d/90-kiosk.conf <<'SYS' || true
vm.swappiness = 10
vm.dirty_writeback_centisecs = 1500
kernel.sysrq = 0
SYS
sysctl -q --system >/dev/null
log "done"
