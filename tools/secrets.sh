#!/usr/bin/env bash
# Copy secrets between the repo's git-ignored secrets/ folder and a device's /opt/kiosk/secrets.
#   tools/secrets.sh push <name> <user@host>    secrets/common/* then secrets/<name>/* → device (root, 0600), then kioskctl apply
#   tools/secrets.sh pull <name> <user@host>    device → secrets/<name>/ (keys generated on the device, config backup)
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
cmd="${1:-}"; name="${2:-}"; host="${3:-}"
[ -n "$cmd" ] && [ -n "$name" ] && [ -n "$host" ] || { sed -n '2,4p' "$0"; exit 1; }
ssh_opts=(-o BatchMode=yes -o ConnectTimeout=8)
case "$cmd" in
    push)
        stage="$(mktemp -d)"; trap 'rm -rf "$stage"' EXIT
        [ -d secrets/common ] && cp -a secrets/common/. "$stage/"
        [ -d "secrets/$name" ] && cp -a "secrets/$name/." "$stage/"
        [ -n "$(ls -A "$stage")" ] || { echo "nothing to push: secrets/common/ and secrets/$name/ are empty" >&2; exit 1; }
        echo "pushing: $(cd "$stage" && find . -type f | sed 's|^\./||' | tr '\n' ' ')"
        tar -C "$stage" -czf - . | ssh "${ssh_opts[@]}" "$host" '
            set -e
            mode="$(cat /etc/kiosk-persistence 2>/dev/null || echo rw)"
            [ "$mode" != locked ] || { echo "device is locked: secrets would vanish at reboot. Use data or rw mode." >&2; exit 1; }
            sudo -n install -d -m 0700 /opt/kiosk/secrets
            sudo -n tar -C /opt/kiosk/secrets -xzf -
            sudo -n chown -R root:root /opt/kiosk/secrets
            sudo -n find /opt/kiosk/secrets -type d -exec chmod 0700 {} +
            sudo -n find /opt/kiosk/secrets -type f -exec chmod 0600 {} +
            sudo -n kioskctl apply 2>&1 | grep -v "wrote" || true
            echo "secrets on $(hostname): $(sudo -n find /opt/kiosk/secrets -type f | wc -l) files"' ;;
    pull)
        mkdir -p "secrets/$name"
        ssh "${ssh_opts[@]}" "$host" 'sudo -n tar -C /opt/kiosk/secrets -czf - .' | tar -C "secrets/$name" -xzf -
        chmod -R go-rwx "secrets/$name"
        echo "pulled into secrets/$name/: $(cd "secrets/$name" && find . -type f | sed 's|^\./||' | tr '\n' ' ')" ;;
    *) sed -n '2,4p' "$0"; exit 1 ;;
esac
