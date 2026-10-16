#!/usr/bin/env bash
# Default configuration and first apply.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="config"

if [ ! -f "$KIOSK_CONFIG" ]; then
    install -m 0644 "${KIOSK_SYS}/config/kiosk.default.yaml" "$KIOSK_CONFIG"
    log "default config written to $KIOSK_CONFIG"
else
    log "config exists, left untouched"
fi
install -d -m 0700 "$KIOSK_SECRETS"
for f in "${KIOSK_SYS}"/secrets.example/*.env; do
    [ -f "$f" ] || continue
    [ -f "${KIOSK_SECRETS}/$(basename "$f")" ] || install -m 0600 "$f" "${KIOSK_SECRETS}/"
done

echo "$(cd "$KIOSK_SYS" && git describe --always --dirty 2>/dev/null || date +%Y%m%d)" > "${KIOSK_DIR}/VERSION"
kioskctl apply || warn "apply reported problems; fix the config and run: sudo kioskctl apply"
