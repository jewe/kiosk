#!/usr/bin/env bash
# One-stick unattended install: repacks the stock Ubuntu Server ISO with
#   - `autoinstall` on the kernel command line (no "Continue with autoinstall?" prompt)
#   - the rendered user-data embedded as /autoinstall.yaml
# Needs xorriso (macOS: brew install xorriso). Write the result with balenaEtcher or dd.
#
#   ./make-iso.sh --iso ~/Downloads/ubuntu-26.04.1-live-server-amd64.iso --hostname kiosk-02 [make-cidata.sh options]
#   → out/kiosk-02/kiosk-02.iso
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
iso=""; args=(); hostname=""
while [ $# -gt 0 ]; do
    case "$1" in
        --iso) iso="$2"; shift 2 ;;
        --hostname) hostname="$2"; args+=("$1" "$2"); shift 2 ;;
        -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
        *) args+=("$1"); shift ;;
    esac
done
[ -f "$iso" ] || { echo "--iso <ubuntu-server.iso> is required" >&2; exit 1; }
[ -n "$hostname" ] || { echo "--hostname is required" >&2; exit 1; }
command -v xorriso >/dev/null || { echo "xorriso missing (brew install xorriso / apt install xorriso)" >&2; exit 1; }

"$here/make-cidata.sh" "${args[@]}"          # renders out/<hostname>/user-data
out="$here/out/$hostname"
work="$(mktemp -d)"; trap 'rm -rf "$work"' EXIT

# grub.cfg from the ISO: add `autoinstall` to every linux line, short timeout
xorriso -osirrox on -indev "$iso" -extract /boot/grub/grub.cfg "$work/grub.cfg" >/dev/null 2>&1
chmod u+w "$work/grub.cfg"
sed -i.bak -E 's/^(\s*linux\s+\S+)(.*)$/\1 autoinstall\2/; s/^set timeout=.*/set timeout=1/' "$work/grub.cfg"
grep -q 'autoinstall' "$work/grub.cfg" || { echo "could not patch grub.cfg" >&2; exit 1; }

xorriso -indev "$iso" -outdev "$out/$hostname.iso" \
    -boot_image any replay \
    -map "$work/grub.cfg" /boot/grub/grub.cfg \
    -map "$out/user-data" /autoinstall.yaml \
    -volid "KIOSK-$(echo "$hostname" | tr a-z A-Z | cut -c1-20)" >/dev/null 2>&1
echo "iso: $out/$hostname.iso"
echo "write it to a stick (balenaEtcher, or: sudo dd if=$out/$hostname.iso of=/dev/rdiskN bs=4m), boot, done. No CIDATA stick, no keypress."
