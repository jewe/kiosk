#!/usr/bin/env bash
# Shared helpers for all kiosk scripts. Source this file, do not execute it.
# shellcheck disable=SC2034

KIOSK_SYS="${KIOSK_SYS:-/opt/kiosksystem}"   # immutable git checkout
KIOSK_DIR="${KIOSK_DIR:-/opt/kiosk}"         # mutable runtime directory
KIOSK_USER="${KIOSK_USER:-kiosk}"
KIOSK_CONFIG="${KIOSK_DIR}/config/kiosk.yaml"
KIOSK_STATE="${KIOSK_DIR}/state"
KIOSK_SECRETS="${KIOSK_DIR}/secrets"

export DEBIAN_FRONTEND=noninteractive

log()  { printf '[%s] %s\n' "${LOG_TAG:-kiosk}" "$*"; }
warn() { printf '[%s] WARNING: %s\n' "${LOG_TAG:-kiosk}" "$*" >&2; }
die()  { printf '[%s] ERROR: %s\n' "${LOG_TAG:-kiosk}" "$*" >&2; exit 1; }

require_root() {
    [ "$(id -u)" -eq 0 ] || die "run as root (sudo)"
}

# apt_install pkg...  Installs only packages that are missing.
apt_install() {
    local missing=()
    local pkg
    for pkg in "$@"; do
        dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "install ok installed" || missing+=("$pkg")
    done
    if [ "${#missing[@]}" -gt 0 ]; then
        log "installing: ${missing[*]}"
        apt-get install -y --no-install-recommends "${missing[@]}"
    fi
}

apt_update_once() {
    if [ -z "${_KIOSK_APT_UPDATED:-}" ]; then
        apt-get update
        export _KIOSK_APT_UPDATED=1
    fi
}

# write_file <path> <mode>  (content on stdin). Writes only when content differs.
# Returns 0 when the file was changed, 1 when unchanged.
write_file() {
    local path="$1" mode="${2:-0644}" tmp
    tmp="$(mktemp)"
    cat > "$tmp"
    if [ -f "$path" ] && cmp -s "$tmp" "$path"; then
        rm -f "$tmp"
        chmod "$mode" "$path"
        return 1
    fi
    mkdir -p "$(dirname "$path")"
    install -m "$mode" "$tmp" "$path"
    rm -f "$tmp"
    log "wrote $path"
    return 0
}

# cfg <yq-expression> [default]   Reads a value from kiosk.yaml.
cfg() {
    local expr="$1" default="${2:-}" val
    [ -f "$KIOSK_CONFIG" ] || { printf '%s' "$default"; return; }
    val="$(yq -r "$expr // \"\"" "$KIOSK_CONFIG" 2>/dev/null || true)"
    if [ -z "$val" ] || [ "$val" = "null" ]; then
        printf '%s' "$default"
    else
        printf '%s' "$val"
    fi
}

overlayroot_active() {
    grep -qs ' /media/root-ro ' /proc/mounts
}

# run_on_real_root <cmd...>  Runs a command on the real root filesystem,
# through overlayroot-chroot when the overlay is active.
run_on_real_root() {
    if overlayroot_active; then
        overlayroot-chroot "$@"
    else
        "$@"
    fi
}

# has_gpu intel|amd|nvidia   Matches on the PCI vendor id of display controllers,
# not on names ("Corporation" contains "ati").
has_gpu() {
    local vid
    case "$1" in
        intel)  vid=8086 ;;
        amd)    vid=1002 ;;
        nvidia) vid=10de ;;
        *) return 1 ;;
    esac
    lspci -nn 2>/dev/null | grep -i 'vga\|3d\|display' | grep -q "\[${vid}:"
}
