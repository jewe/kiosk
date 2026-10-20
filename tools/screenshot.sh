#!/usr/bin/env bash
# Screenshot of the kiosk display (scrot, fallback: import). Prints the file path.
#   screenshot.sh [file]      default: /opt/kiosk/data/screenshots/<host>-<timestamp>.png
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
out="${1:-}"
if [ -z "$out" ]; then out="${KIOSK_DIR}/data/screenshots/$(hostname)-$(date +%Y%m%d-%H%M%S).png"; fi
mkdir -p "$(dirname "$out")"
xenv=(DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority")
run() { if [ "$(id -u)" -eq 0 ]; then sudo -u "$KIOSK_USER" env "${xenv[@]}" "$@"; else env "${xenv[@]}" "$@"; fi; }
tmp="$(mktemp --suffix=.png)"; chmod 644 "$tmp"
if command -v scrot >/dev/null; then run scrot -o "$tmp" 2>/dev/null; else run import -window root "$tmp" 2>/dev/null; fi
[ -s "$tmp" ] || { rm -f "$tmp"; echo "screenshot failed (X not reachable?)" >&2; exit 1; }
mv -f "$tmp" "$out" && echo "$out"
