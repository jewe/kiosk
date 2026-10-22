#!/usr/bin/env bash
# Faster boot: drop services a kiosk never uses, no crash kernel, no snap/apport/cloud-init.
# Measured on kiosk-01/02 (Ubuntu 26.04): kdump alone cost 3 s and 512 MB RAM. Everything here is reversible
# with systemctl unmask / apt install.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="boot"

# crash dumps: reserve RAM and 3 s at boot; a kiosk reboots instead of debugging a kernel crash
if dpkg -l kdump-tools 2>/dev/null | grep -q '^ii'; then
    DEBIAN_FRONTEND=noninteractive apt-get purge -y -q kdump-tools linux-crashdump >/dev/null 2>&1 || true
    rm -f /etc/default/grub.d/kdump-tools.cfg
    log "kdump removed (crashkernel reservation gone after the next reboot)"
fi

# cloud-init only matters for the first boot (autoinstall); the units still cost time on every boot
[ -f /etc/cloud/cloud-init.disabled ] || touch /etc/cloud/cloud-init.disabled

units=(
    cloud-init-local.service cloud-init-main.service cloud-init-network.service cloud-config.service cloud-final.service cloud-init-hotplugd.socket
    multipathd.service multipathd.socket open-iscsi.service iscsid.socket iscsid.service
    apport.service apport-autoreport.path apport-autoreport.timer apport-forward.socket
    e2scrub_reap.service e2scrub_all.timer secureboot-db.service
    lxd-installer.socket ModemManager.service fwupd.service fwupd-refresh.timer motd-news.timer
)
for u in "${units[@]}"; do
    systemctl list-unit-files "$u" >/dev/null 2>&1 || continue
    systemctl disable --now "$u" >/dev/null 2>&1 || true
    systemctl mask "$u" >/dev/null 2>&1 || true
done
log "unused services masked: cloud-init, multipath, iscsi, apport, e2scrub, secureboot-db, modem, fwupd"

# the boot menu: hidden, no wait (hold Shift during boot still opens it)
if [ -f /etc/default/grub ] && grep -q '^GRUB_TIMEOUT=1' /etc/default/grub; then
    sed -i 's/^GRUB_TIMEOUT=1/GRUB_TIMEOUT=0/' /etc/default/grub
    run_on_real_root update-grub >/dev/null 2>&1 && log "GRUB timeout 0" || warn "update-grub failed"
fi
log "done"
