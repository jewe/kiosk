#!/usr/bin/env bash
# Kiosk user, runtime directories, kioskctl in PATH.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="user"

if ! id "$KIOSK_USER" >/dev/null 2>&1; then
    useradd -m -s /bin/bash -c "Kiosk" "$KIOSK_USER"
    log "created user $KIOSK_USER"
fi
passwd -l "$KIOSK_USER" >/dev/null
for g in video input audio render tty plugdev; do
    getent group "$g" >/dev/null && usermod -aG "$g" "$KIOSK_USER"
done

mkdir -p "$KIOSK_DIR"/{config,apps,data,logs,state/apps}
mkdir -p "$KIOSK_SECRETS"
chown -R "$KIOSK_USER:$KIOSK_USER" "$KIOSK_DIR"/{apps,data,state}
chown root:root "$KIOSK_DIR" "$KIOSK_DIR/config" "$KIOSK_DIR/logs" "$KIOSK_SECRETS"
chmod 0755 "$KIOSK_DIR" "$KIOSK_DIR/config"
chmod 0700 "$KIOSK_SECRETS"

ln -sfn "${KIOSK_SYS}/bin/kioskctl" /usr/local/bin/kioskctl

# the kiosk user may read status and restart its own apps, nothing else
write_file /etc/sudoers.d/90-kiosk 0440 <<SUDO || true
$KIOSK_USER ALL=(root) NOPASSWD: /usr/local/bin/kioskctl status*, /usr/local/bin/kioskctl app *
SUDO
log "done"
