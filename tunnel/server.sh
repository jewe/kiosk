#!/usr/bin/env bash
# Tunnel server setup, run as root on the server from the Mac:
#   ssh root@<server> bash -s -- setup                              < tunnel/server.sh
#   ssh root@<server> bash -s -- add <name> <port> '<ssh-ed25519 …>' < tunnel/server.sh
#   ssh root@<server> bash -s -- remove <name>                      < tunnel/server.sh
#   ssh root@<server> bash -s -- list                               < tunnel/server.sh
# setup: user `tunnel` (no shell) + sshd drop-in for it. add: one authorized_keys line per kiosk, allowed to
# listen only on its <port> (loopback: GatewayPorts no). Idempotent. Nothing to install: stock OpenSSH does it.
set -euo pipefail
USER_NAME=tunnel
HOME_DIR=/home/$USER_NAME
AK=$HOME_DIR/.ssh/authorized_keys
DROPIN=/etc/ssh/sshd_config.d/50-kiosk-tunnel.conf

die() { echo "error: $*" >&2; exit 1; }
[ "$(id -u)" = 0 ] || die "run as root"

case "${1:-}" in
setup)
    if ! id "$USER_NAME" >/dev/null 2>&1; then
        adduser --system --group --shell /usr/sbin/nologin --home "$HOME_DIR" "$USER_NAME"
    fi
    install -d -m 0700 -o "$USER_NAME" -g "$USER_NAME" "$HOME_DIR/.ssh"
    [ -f "$AK" ] || install -m 0600 -o "$USER_NAME" -g "$USER_NAME" /dev/null "$AK"
    cat > "$DROPIN.new" <<'EOF'
# kiosk reverse tunnels (kiosk repo: tunnel/README.md). Ports bind to localhost only.
Match User tunnel
    AllowTcpForwarding remote
    GatewayPorts no
    PermitTTY no
    X11Forwarding no
    AllowAgentForwarding no
    PermitTunnel no
    ClientAliveInterval 30
    ClientAliveCountMax 3
EOF
    mv "$DROPIN.new" "$DROPIN"
    sshd -t || { rm -f "$DROPIN"; die "sshd -t failed, drop-in removed"; }
    systemctl reload ssh 2>/dev/null || systemctl reload sshd
    echo "ok: user $USER_NAME, $DROPIN"
    sshd -T -C user=$USER_NAME,host=x,addr=127.0.0.1 | grep -Ei '^(allowtcpforwarding|gatewayports|permittty|clientalive)'
    ;;
add)
    name="${2:-}" port="${3:-}" key="${4:-}"
    [ -n "$name" ] && [[ "$port" =~ ^[0-9]+$ ]] && [[ "$key" =~ ^ssh-(ed25519|rsa)\ [A-Za-z0-9+/=]+ ]] \
        || die "usage: add <name> <port> '<public key>'"
    [ -f "$AK" ] || die "run setup first"
    if grep -v " kiosk:$name\$" "$AK" | grep -q "permitlisten=\"$port\""; then
        die "port $port already belongs to: $(grep "permitlisten=\"$port\"" "$AK" | awk '{print $NF}')"
    fi
    keypart="$(echo "$key" | awk '{print $1" "$2}')"
    { grep -v " kiosk:$name\$" "$AK" || true
      echo "restrict,port-forwarding,permitlisten=\"$port\" $keypart kiosk:$name"
    } > "$AK.new"
    install -m 0600 -o "$USER_NAME" -g "$USER_NAME" "$AK.new" "$AK"; rm -f "$AK.new"
    echo "ok: $name → port $port"
    ;;
remove)
    name="${2:-}"; [ -n "$name" ] || die "usage: remove <name>"
    { grep -v " kiosk:$name\$" "$AK" || true; } > "$AK.new"
    install -m 0600 -o "$USER_NAME" -g "$USER_NAME" "$AK.new" "$AK"; rm -f "$AK.new"
    echo "ok: $name removed (an open tunnel stays up until it reconnects)"
    ;;
list)
    listening="$(ss -Htln | awk '{print $4}')"
    sed -n 's/.*permitlisten="\([0-9]*\)".* kiosk:\(.*\)$/\2 \1/p' "$AK" 2>/dev/null | sort -k2n |
    while read -r name port; do
        if grep -qx "127.0.0.1:$port" <<<"$listening"; then st=up; else st=down; fi
        printf '%-16s %6s  %s\n' "$name" "$port" "$st"
    done
    ;;
*) die "usage: setup | add <name> <port> <key> | remove <name> | list" ;;
esac
