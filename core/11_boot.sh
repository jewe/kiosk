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

# GRUB in text mode: gfxterm (mode switch + font from LVM) cost 2.7 s in the loader on a Celeron N3000
# (wetho, 7.8 → 5.0 s). The menu is hidden anyway; plymouth still draws the splash from the kernel's framebuffer.
if [ -d /etc/default/grub.d ] && [ ! -f /etc/default/grub.d/80-kiosk-terminal.cfg ]; then
    echo 'GRUB_TERMINAL=console' > /etc/default/grub.d/80-kiosk-terminal.cfg
    run_on_real_root update-grub >/dev/null 2>&1 && log "GRUB text mode" || warn "update-grub failed"
fi

# ufw no longer holds back the network: the stock unit is ordered Before=network-pre.target, so NetworkManager,
# network.target, systemd-user-sessions and with them the kiosk session waited 4-5 s for the iptables-nft rules
# on slow CPUs. Loaded in parallel instead. The gap is harmless as long as nothing but sshd (allowed by ufw anyway)
# listens on the network: nginx serves on 127.0.0.1 only (its default site is removed by apps/web). A drop-in
# cannot remove Before=, hence a full copy of the unit; undo with rm + daemon-reload.
if [ -f /usr/lib/systemd/system/ufw.service ]; then
    write_file /etc/systemd/system/ufw.service <<'UFW' && systemctl daemon-reload && log "ufw loads in parallel with the network" || true
# kiosk: copy of the ufw unit without Before=/Wants=network-pre.target (core/11_boot.sh)
[Unit]
Description=Uncomplicated firewall
Documentation=man:ufw(8)
DefaultDependencies=no
Wants=local-fs.target
After=local-fs.target

[Service]
Type=oneshot
RemainAfterExit=yes
ExecStart=/usr/lib/ufw/ufw-init start quiet
ExecStop=/usr/lib/ufw/ufw-init stop

[Install]
WantedBy=multi-user.target
UFW
fi
log "done"
