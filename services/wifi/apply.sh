#!/usr/bin/env bash
# network.wifi: up to 3 service WLANs as NetworkManager profiles, credentials from secrets/wifi.env.
# Profile kiosk-<name> gets autoconnect priority 100, 90, 80 in list order.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="wifi"
command -v nmcli >/dev/null || { warn "NetworkManager not installed"; exit 0; }
[ -f "${KIOSK_SECRETS}/wifi.env" ] && { set -a; source "${KIOSK_SECRETS}/wifi.env"; set +a; }

wanted=()
n="$(cfg '.network.wifi | length' 0)"
[ "$n" -le 3 ] || { warn "network.wifi: only the first 3 entries are used"; n=3; }
for ((i=0; i<n; i++)); do
    name="$(cfg ".network.wifi[$i]")"
    [[ "$name" =~ ^[a-z0-9_-]+$ ]] || { warn "wifi name '$name' must be [a-z0-9_-]"; continue; }
    key="${name^^}"; key="${key//-/_}"
    ssid_var="WIFI_${key}_SSID"; psk_var="WIFI_${key}_PSK"
    ssid="${!ssid_var:-}"; psk="${!psk_var:-}"
    [ -n "$ssid" ] || { warn "no ${ssid_var} in ${KIOSK_SECRETS}/wifi.env"; continue; }
    con="kiosk-${name}"; prio=$((100 - i*10)); wanted+=("$con")
    if nmcli -t -f NAME con show | grep -qx "$con"; then
        nmcli con modify "$con" 802-11-wireless.ssid "$ssid" connection.autoconnect-priority "$prio" >/dev/null
    else
        nmcli con add type wifi con-name "$con" ifname '*' ssid "$ssid" connection.autoconnect yes connection.autoconnect-priority "$prio" >/dev/null
    fi
    if [ -n "$psk" ]; then
        nmcli con modify "$con" wifi-sec.key-mgmt wpa-psk wifi-sec.psk "$psk" >/dev/null
    else
        nmcli con modify "$con" remove wifi-sec >/dev/null 2>&1 || true
    fi
    log "profile $con → '$ssid' (priority $prio)"
done
# drop profiles no longer configured
while read -r con; do
    [ -n "$con" ] || continue
    [[ " ${wanted[*]:-} " == *" $con "* ]] && continue
    nmcli con delete "$con" >/dev/null && log "removed profile $con"
done < <(nmcli -t -f NAME con show | grep '^kiosk-' || true)
