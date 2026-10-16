#!/usr/bin/env bash
# Sync the app repo and the data repo of a static app; run the configured action on change.
#   update.sh <name>     (also run by kiosk-content-update@<name>.service/.timer)
# Env (from /opt/kiosk/state/apps/<name>.env): APP_REPO, APP_BRANCH, APP_DATA_REPO, APP_DATA_BRANCH,
#   APP_ON_APP_CHANGE (restart), APP_ON_DATA_CHANGE (reload)
# Private repos: deploy key /opt/kiosk/secrets/git/id_ed25519 (kioskctl secrets git-key).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:static"
name="${1:?name}"
set -a; source "${KIOSK_STATE}/apps/${name}.env"; set +a
appdir="${KIOSK_DIR}/apps/${name}"

gitkey="${KIOSK_SECRETS}/git/id_ed25519"
if [ -f "$gitkey" ]; then
    export GIT_SSH_COMMAND="ssh -i $gitkey -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${KIOSK_SECRETS}/git/known_hosts -o BatchMode=yes"
else
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
fi
# runs as root (content dirs are root-owned, world-readable for nginx)
g() { timeout 120 git -c safe.directory='*' "$@"; }

# sync_repo <url> <branch> <dir>  → echoes cloned|changed|unchanged|failed
sync_repo() {
    local url="$1" branch="${2:-main}" dir="$3" before after
    if [ -d "$dir/.git" ]; then
        before="$(g -C "$dir" rev-parse HEAD 2>/dev/null)"
        g -C "$dir" fetch -q --depth 1 origin "$branch" 2>/dev/null || { echo failed; return; }
        g -C "$dir" reset -q --hard FETCH_HEAD 2>/dev/null || { echo failed; return; }
        after="$(g -C "$dir" rev-parse HEAD 2>/dev/null)"
        [ "$before" = "$after" ] && echo unchanged || echo "changed ${before:0:7}->${after:0:7}"
    else
        mkdir -p "$(dirname "$dir")"
        if g clone -q --depth 1 --branch "$branch" "$url" "$dir" 2>/dev/null; then echo "cloned $(g -C "$dir" rev-parse --short HEAD)"; else rm -rf "$dir"; echo failed; fi
    fi
}

reload_window() {
    local wid
    wid="$(sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority" xdotool search --onlyvisible --class "kiosk-${name}" 2>/dev/null | head -1)"
    [ -n "$wid" ] || { warn "$name: no window to reload, restarting instead"; systemctl try-restart "kiosk-static@${name}.service"; return; }
    sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority" xdotool windowactivate --sync "$wid" key --clearmodifiers F5 2>/dev/null
}
act() {  # act <what> <action>
    case "$2" in
        restart) systemctl try-restart "kiosk-static@${name}.service" && log "$name: restarted ($1 changed)" ;;
        reload)  reload_window && log "$name: page reloaded ($1 changed)" ;;
        none)    log "$name: $1 changed, no action" ;;
        *)       warn "$name: unknown action '$2'" ;;
    esac
}

rc=0
if [ -n "${APP_REPO:-}" ]; then
    r="$(sync_repo "$APP_REPO" "${APP_BRANCH:-main}" "$appdir/repo")"; log "$name app: $r"
    case "$r" in changed*) act app "${APP_ON_APP_CHANGE:-restart}" ;; failed) rc=1 ;; esac
fi
if [ -n "${APP_DATA_REPO:-}" ]; then
    r="$(sync_repo "$APP_DATA_REPO" "${APP_DATA_BRANCH:-main}" "$appdir/data")"; log "$name data: $r"
    case "$r" in changed*) act data "${APP_ON_DATA_CHANGE:-reload}" ;; failed) rc=1 ;; esac
fi
if [ "$rc" = 1 ] && [ ! -f "$gitkey" ] && [[ "${APP_REPO:-}${APP_DATA_REPO:-}" == *"git@"* || "${APP_REPO:-}${APP_DATA_REPO:-}" == *"ssh://"* ]]; then
    warn "ssh repo without deploy key: run 'kioskctl secrets git-key' and add the key to the repos"
fi
exit $rc
