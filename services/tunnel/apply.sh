#!/usr/bin/env bash
# services.tunnel: reverse SSH tunnel to a server (SSH only). Key pair is generated on first apply.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="tunnel"
keydir="${KIOSK_SECRETS}/tunnel"

install -m 0644 "${KIOSK_SYS}/services/tunnel/kiosk-tunnel.service" /etc/systemd/system/
if [ "$(cfg '.services.tunnel.enabled' false)" != "true" ]; then
    systemctl disable --now kiosk-tunnel.service >/dev/null 2>&1 || true
    exit 0
fi
host="$(cfg '.services.tunnel.host')"
[ -n "$host" ] || { warn "services.tunnel.host is empty"; exit 1; }
install -d -m 0700 "$keydir"
if [ ! -f "$keydir/id_ed25519" ]; then
    ssh-keygen -q -t ed25519 -N "" -C "kiosk-$(hostname)" -f "$keydir/id_ed25519"
    log "tunnel key generated"
fi
touch "$keydir/known_hosts"
{
    echo "TUNNEL_HOST=$host"
    echo "TUNNEL_PORT=$(cfg '.services.tunnel.port' 22)"
    echo "TUNNEL_USER=$(cfg '.services.tunnel.user' tunnel)"
    echo "TUNNEL_REMOTE_PORT=$(cfg '.services.tunnel.remote_port' 20022)"
} | write_file "${KIOSK_STATE}/tunnel.env" 0600 || true
systemctl daemon-reload
systemctl enable kiosk-tunnel.service >/dev/null 2>&1
systemctl restart kiosk-tunnel.service || true
log "tunnel to $host enabled. Public key to authorize on the server:"
cat "$keydir/id_ed25519.pub"
