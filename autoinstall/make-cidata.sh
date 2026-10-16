#!/usr/bin/env bash
# Builds the CIDATA stick (or image) for an unattended Ubuntu Server install. Runs on macOS or Linux.
#
#   ./make-cidata.sh --hostname kiosk-01 [--key ~/.ssh/id_ed25519.pub] [--repo URL]
#                    [--locale de_DE.UTF-8] [--keyboard de] [--timezone Europe/Berlin]
#                    [--user kioskadmin] [--password-hash '$6$...']
#                    [--root-size 24G] [--data-size 8G]      (disk needs 3G + root + data)
#                    [--img out/cidata.img | --disk /dev/diskN]
#
# Without --img/--disk the rendered files are written to out/<hostname>/ only.
# Then boot the PC from the Ubuntu Server ISO stick with the CIDATA stick plugged in
# and confirm "Continue with autoinstall?" once.
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

hostname="" key="${HOME}/.ssh/id_ed25519.pub" repo="https://github.com/jewe/kiosk.git"
locale="de_DE.UTF-8" keyboard="de" timezone="Europe/Berlin" user="kioskadmin" hash="" img="" disk="" root_size="24G" data_size="8G"
while [ $# -gt 0 ]; do
    case "$1" in
        --hostname) hostname="$2"; shift 2 ;;
        --key) key="$2"; shift 2 ;;
        --repo) repo="$2"; shift 2 ;;
        --locale) locale="$2"; shift 2 ;;
        --keyboard) keyboard="$2"; shift 2 ;;
        --timezone) timezone="$2"; shift 2 ;;
        --user) user="$2"; shift 2 ;;
        --password-hash) hash="$2"; shift 2 ;;
        --root-size) root_size="$2"; shift 2 ;;
        --data-size) data_size="$2"; shift 2 ;;
        --img) img="$2"; shift 2 ;;
        --disk) disk="$2"; shift 2 ;;
        -h|--help) sed -n '2,12p' "$0"; exit 0 ;;
        *) echo "unknown option $1" >&2; exit 1 ;;
    esac
done
[ -n "$hostname" ] || { echo "--hostname is required" >&2; exit 1; }
[ -f "$key" ] || { echo "ssh public key not found: $key (use --key)" >&2; exit 1; }

if [ -z "$hash" ]; then
    echo "Password for user '$user' (console only, SSH is key-only):"
    read -r -s pw1; echo "again:"; read -r -s pw2
    [ "$pw1" = "$pw2" ] && [ -n "$pw1" ] || { echo "passwords differ or empty" >&2; exit 1; }
    hash="$(printf '%s' "$pw1" | openssl passwd -6 -stdin)"
fi

out="$here/out/$hostname"
mkdir -p "$out"
sshkey="$(tr -d '\n' < "$key")"
HOSTNAME_="$hostname" USER_="$user" HASH_="$hash" KEY_="$sshkey" REPO_="$repo" LOCALE_="$locale" KB_="$keyboard" TZ_="$timezone" ROOT_="$root_size" DATA_="$data_size" \
python3 -I - "$here/user-data.template" "$out/user-data" <<'PY'
import os, sys
t = open(sys.argv[1]).read()
for k, v in {"__HOSTNAME__": "HOSTNAME_", "__USERNAME__": "USER_", "__PASSWORD_HASH__": "HASH_", "__SSH_KEY__": "KEY_",
             "__REPO_URL__": "REPO_", "__LOCALE__": "LOCALE_", "__KEYBOARD__": "KB_", "__TIMEZONE__": "TZ_",
             "__ROOT_SIZE__": "ROOT_", "__DATA_SIZE__": "DATA_"}.items():
    t = t.replace(k, os.environ[v])
open(sys.argv[2], "w").write(t)
PY
cp "$here/meta-data" "$out/meta-data"
echo "rendered: $out/user-data, $out/meta-data  (root ${root_size}, data ${data_size}; disk must have at least 3G + root + data)"

if [ -n "$img" ]; then
    mkdir -p "$(dirname "$img")"
    if [ "$(uname)" = "Darwin" ]; then
        tmpdmg="${img%.img}.dmg"; rm -f "$img" "$tmpdmg"
        hdiutil create -quiet -size 8m -fs "MS-DOS FAT12" -volname CIDATA -srcfolder "$out" -format UDRW -ov "$tmpdmg"
        mv "$tmpdmg" "$img"
    else
        command -v mkfs.vfat >/dev/null && command -v mcopy >/dev/null || { echo "need dosfstools and mtools" >&2; exit 1; }
        dd if=/dev/zero of="$img" bs=1M count=8 status=none
        mkfs.vfat -n CIDATA "$img" >/dev/null
        mcopy -i "$img" "$out/user-data" "$out/meta-data" ::
    fi
    echo "image: $img  (attach as a second disk in a VM, or dd it to a stick)"
fi

if [ -n "$disk" ]; then
    echo "This will ERASE $disk and label it CIDATA."
    diskutil info "$disk" 2>/dev/null | grep -E 'Device / Media Name|Disk Size' || lsblk "$disk" 2>/dev/null || true
    read -r -p "type YES to continue: " ok; [ "$ok" = "YES" ] || exit 1
    if [ "$(uname)" = "Darwin" ]; then
        diskutil eraseDisk FAT32 CIDATA MBRFormat "$disk"
        cp "$out/user-data" "$out/meta-data" /Volumes/CIDATA/
        diskutil eject "$disk"
    else
        mkfs.vfat -I -n CIDATA "$disk"
        m="$(mktemp -d)"; mount "$disk" "$m"; cp "$out/user-data" "$out/meta-data" "$m/"; umount "$m"; rmdir "$m"
    fi
    echo "stick ready: $disk"
fi
