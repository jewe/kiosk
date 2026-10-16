#!/usr/bin/env bash
# Kiosk base setup. Runs the numbered modules in core/ in order.
# Idempotent: safe to run again after a git pull.
#
#   sudo ./setup.sh                 run all modules
#   sudo ./setup.sh --only 03,08    run selected modules (by number prefix)
#   sudo ./setup.sh --skip 09       run all but the listed ones
#   sudo ./setup.sh --list          show modules and exit

set -euo pipefail
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${BASE_DIR}/lib/common.sh"
LOG_TAG="setup"

only="" skip="" list=0
while [ $# -gt 0 ]; do
    case "$1" in
        --only) only="$2"; shift 2 ;;
        --skip) skip="$2"; shift 2 ;;
        --list) list=1; shift ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) die "unknown option: $1" ;;
    esac
done

modules=("${BASE_DIR}"/core/[0-9][0-9]_*.sh)
if [ "$list" -eq 1 ]; then
    for m in "${modules[@]}"; do basename "$m"; done
    exit 0
fi

require_root
[ -d "$KIOSK_SYS" ] || warn "repo is not at $KIOSK_SYS; scripts assume that path on the device"

selected() {
    local num="$1"
    if [ -n "$only" ]; then
        [[ ",$only," == *",$num,"* ]]
    elif [ -n "$skip" ]; then
        [[ ",$skip," != *",$num,"* ]]
    fi
}

mkdir -p "${KIOSK_DIR}/logs"
logfile="${KIOSK_DIR}/logs/setup-$(date +%Y%m%d-%H%M%S).log"
exec > >(tee -a "$logfile") 2>&1
log "log: $logfile"

apt_update_once
for m in "${modules[@]}"; do
    name="$(basename "$m")"
    num="${name%%_*}"
    selected "$num" || { log "skip $name"; continue; }
    echo
    log "==== $name ===="
    bash "$m"
done

echo
log "setup complete. Next steps:"
log "  1. install an app type, e.g. sudo ${KIOSK_SYS}/apps/web/install.sh"
log "  2. edit ${KIOSK_CONFIG} and run: sudo kioskctl apply"
log "  3. reboot"
