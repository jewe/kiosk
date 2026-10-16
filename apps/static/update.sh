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

# GitHub allows a deploy key on one repository only, so each repo may have its own key:
#   secrets/git/<app>-app, secrets/git/<app>-data (kioskctl secrets git-key <label>), fallback secrets/git/id_ed25519
gitkey=""
use_key() {  # use_key <label>
    local k
    for k in "${KIOSK_SECRETS}/git/$1" "${KIOSK_SECRETS}/git/id_ed25519"; do
        if [ -f "$k" ]; then
            gitkey="$k"
            export GIT_SSH_COMMAND="ssh -i $k -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${KIOSK_SECRETS}/git/known_hosts -o BatchMode=yes"
            return
        fi
    done
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
}
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
    # Ctrl+R sent to the window itself works in Chrome's kiosk mode; F5 via the focused window did not
    sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority" xdotool key --window "$wid" ctrl+r 2>/dev/null
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
    use_key "${name}-app"
    r="$(sync_repo "$APP_REPO" "${APP_BRANCH:-main}" "$appdir/repo")"; log "$name app: $r (key: ${gitkey:-none})"
    case "$r" in changed*) act app "${APP_ON_APP_CHANGE:-restart}" ;; failed) rc=1 ;; esac
fi
if [ -n "${APP_DATA_REPO:-}" ]; then
    use_key "${name}-data"
    r="$(sync_repo "$APP_DATA_REPO" "${APP_DATA_BRANCH:-main}" "$appdir/data")"; log "$name data: $r (key: ${gitkey:-none})"
    case "$r" in changed*) act data "${APP_ON_DATA_CHANGE:-reload}" ;; failed) rc=1 ;; esac
fi
if [ "$rc" = 1 ] && [[ "${APP_REPO:-}${APP_DATA_REPO:-}" == *"git@"* || "${APP_REPO:-}${APP_DATA_REPO:-}" == *"ssh://"* ]]; then
    warn "ssh clone failed: generate keys with 'kioskctl secrets git-key ${name}-app' / '${name}-data' and add them as deploy keys"
fi
exit $rc
