#!/usr/bin/env bash
# Firewall and SSH hardening. Password login is only disabled when the admin has a key.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="security"

apt_install ufw openssh-server
ufw allow OpenSSH >/dev/null
ufw --force enable >/dev/null
log "ufw enabled, ssh allowed"

admin="${SUDO_USER:-}"
has_key=0
if [ -n "$admin" ] && [ -s "/home/$admin/.ssh/authorized_keys" ]; then has_key=1; fi
if [ -s /root/.ssh/authorized_keys ]; then has_key=1; fi

if [ "$has_key" -eq 1 ]; then
    pw="no"
else
    pw="yes"
    warn "no authorized_keys found for ${admin:-root}; keeping SSH password login enabled"
fi
write_file /etc/ssh/sshd_config.d/10-kiosk.conf <<SSH && systemctl reload ssh || true
PermitRootLogin no
PasswordAuthentication $pw
KbdInteractiveAuthentication $pw
X11Forwarding no
ClientAliveInterval 60
ClientAliveCountMax 3
SSH
log "done"
