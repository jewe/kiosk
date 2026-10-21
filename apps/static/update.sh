#!/usr/bin/env bash
# Sync the app repo and the data repos of a static app; run the configured action once if anything changed.
#   update.sh <name> [repo]     repo = app | <data name>; default all   (also run by kiosk-content-update@<name>)
# Env (from /opt/kiosk/state/apps/<name>.env): APP_REPO, APP_BRANCH, APP_ON_APP_CHANGE,
#   APP_DATA_COUNT, APP_DATA_<n>_NAME|REPO|BRANCH|LFS|ON_CHANGE
# Only the latest commit is kept on disk (shallow fetch + gc); lfs=true pulls the LFS objects of that commit only.
# Private repos: deploy key /opt/kiosk/secrets/git/<app>-<repo> (kioskctl secrets git-key <label>), fallback id_ed25519.
# State per repo: /opt/kiosk/apps/<name>/state/<repo>.json (shown by kioskctl status).
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:static"
name="${1:?name}"; only="${2:-}"
set -a; source "${KIOSK_STATE}/apps/${name}.env"; set +a
appdir="${KIOSK_DIR}/apps/${name}"
mkdir -p "$appdir/state"

gitkey=""
use_key() {  # use_key <label>: GitHub allows a deploy key on one repository only, so each repo may have its own
    local k
    for k in "${KIOSK_SECRETS}/git/$1" "${KIOSK_SECRETS}/git/id_ed25519"; do
        if [ -f "$k" ]; then
            gitkey="$k"
            export GIT_SSH_COMMAND="ssh -i $k -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new -o UserKnownHostsFile=${KIOSK_SECRETS}/git/known_hosts -o BatchMode=yes"
            # old git servers accept only ssh-rsa with SHA-1, which modern OpenSSH disables by default
            grep -q '^ssh-rsa' "$k.pub" 2>/dev/null && export GIT_SSH_COMMAND="$GIT_SSH_COMMAND -o PubkeyAcceptedAlgorithms=+ssh-rsa -o HostKeyAlgorithms=+ssh-rsa"
            # optional per-device ssh config (secrets/git/ssh_config): e.g. reach a git server through a tunnel
            [ -f "${KIOSK_SECRETS}/git/ssh_config" ] && export GIT_SSH_COMMAND="$GIT_SSH_COMMAND -F ${KIOSK_SECRETS}/git/ssh_config"
            return
        fi
    done
    export GIT_SSH_COMMAND="ssh -o StrictHostKeyChecking=accept-new -o BatchMode=yes"
}
# runs as root (content dirs are root-owned, world-readable for nginx); LFS smudge off, objects pulled explicitly
g() { GIT_LFS_SKIP_SMUDGE=1 timeout 600 git -c safe.directory='*' "$@"; }
gslow() { GIT_LFS_SKIP_SMUDGE=1 timeout 3600 git -c safe.directory='*' "$@"; }   # clone and fetch of large repos

# drop objects of previous commits once the object store is worth it
gc_repo() {
    local dir="$1" kb
    kb="$(du -sk "$dir/.git" 2>/dev/null | cut -f1)"
    [ "${kb:-0}" -gt 51200 ] || return 0
    g -C "$dir" reflog expire --expire=now --all 2>/dev/null
    g -C "$dir" gc -q --prune=now 2>/dev/null && log "$name: $(basename "$dir") gc, .git now $(du -sh "$dir/.git" | cut -f1)" >&2
}

# lfs_sync <dir>: objects of the checked-out commit only
lfs_sync() {
    local dir="$1"
    command -v git-lfs >/dev/null || apt_install git-lfs >&2 || { warn "$name: lfs=true but git-lfs could not be installed"; return 1; }
    g -C "$dir" config lfs.fetchrecentrefsdays 0; g -C "$dir" config lfs.fetchrecentcommitsdays 0; g -C "$dir" config lfs.pruneoffsetdays 0
    timeout 1800 git -C "$dir" -c safe.directory='*' lfs pull 2>/dev/null || { warn "$name: lfs pull failed in $dir"; return 1; }
    timeout 600 git -C "$dir" -c safe.directory='*' lfs prune -f >/dev/null 2>&1 || true
    lfs_dedup "$dir"
}
# lfs_dedup <dir>: the LFS cache keeps a copy of every checked-out object; replace it with a hard link to the
# working file so large repos use the disk once. git writes new files instead of editing in place, so the link is safe.
lfs_dedup() {
    local dir="$1" oid path obj
    while read -r oid _ path; do
        [ -n "$oid" ] && [ -f "$dir/$path" ] || continue
        obj="$dir/.git/lfs/objects/${oid:0:2}/${oid:2:2}/$oid"
        [ -f "$obj" ] || continue
        [ "$obj" -ef "$dir/$path" ] && continue
        ln -f "$dir/$path" "$obj" 2>/dev/null || true
    done < <(git -C "$dir" -c safe.directory='*' lfs ls-files -l 2>/dev/null)
}

# sync_repo <url> <branch> <dir> <lfs>  → echoes cloned|changed|unchanged|failed; one retry after 15 s (boot, flaky link)
sync_repo() {
    local r
    r="$(sync_repo_once "$@")"
    if [ "$r" = failed ]; then sleep 15; r="$(sync_repo_once "$@")"; fi
    echo "$r"
}
sync_repo_once() {
    local url="$1" branch="${2:-main}" dir="$3" lfs="${4:-false}" before after r
    if [ -d "$dir/.git" ]; then
        [ "$(g -C "$dir" remote get-url origin 2>/dev/null)" = "$url" ] || g -C "$dir" remote set-url origin "$url"
        before="$(g -C "$dir" rev-parse HEAD 2>/dev/null)"
        gslow -C "$dir" fetch -q --depth 1 origin "$branch" 2>/dev/null || { echo failed; return; }
        g -C "$dir" reset -q --hard FETCH_HEAD 2>/dev/null || { echo failed; return; }
        after="$(g -C "$dir" rev-parse HEAD 2>/dev/null)"
        if [ "$before" = "$after" ]; then r=unchanged; else r="changed ${before:0:7}->${after:0:7}"; gc_repo "$dir"; fi
    else
        mkdir -p "$(dirname "$dir")"
        if gslow clone -q --depth 1 --branch "$branch" "$url" "$dir" 2>/dev/null; then r="cloned $(g -C "$dir" rev-parse --short HEAD)"; else rm -rf "$dir"; echo failed; return; fi
    fi
    if [ "$lfs" = true ]; then
        command -v git-lfs >/dev/null || apt_install git-lfs >&2 || true
        # pull when the commit changed or any tracked file is still a pointer ("oid - path" in lfs ls-files)
        if [ "$r" != unchanged ] || ! command -v git-lfs >/dev/null || g -C "$dir" lfs ls-files 2>/dev/null | grep -q '^[0-9a-f]* - '; then
            lfs_sync "$dir" || r=failed
        else
            lfs_dedup "$dir"
        fi
    elif [ -f "$dir/.gitattributes" ] && grep -q 'filter=lfs' "$dir/.gitattributes"; then
        warn "$name: $(basename "$dir") uses Git LFS but lfs is not set: large files are pointer stubs"
    fi
    echo "$r"
}

write_state() {  # write_state <repo> <dir> <result> <lfs>
    local commit="" size=0
    [ -d "$2/.git" ] && commit="$(g -C "$2" rev-parse --short HEAD 2>/dev/null)" && size="$(du -sm "$2" 2>/dev/null | cut -f1)"
    jq -n --arg name "$1" --arg commit "$commit" --arg ts "$(date -u -Is)" --arg result "${3%% *}" --argjson size "${size:-0}" --argjson lfs "$4" \
        '{name:$name, commit:$commit, ts:$ts, result:$result, size_mb:$size, lfs:$lfs}' > "$appdir/state/$1.json"
}

reload_window() {
    local wid
    wid="$(sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority" xdotool search --onlyvisible --class "kiosk-${name}" 2>/dev/null | head -1)"
    [ -n "$wid" ] || { warn "$name: no window to reload, restarting instead"; systemctl try-restart "kiosk-static@${name}.service"; return; }
    # Ctrl+R sent to the window itself works in Chrome's kiosk mode; F5 via the focused window did not
    sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority" xdotool key --window "$wid" ctrl+r 2>/dev/null
}

rc=0; action=none; changed=()
want() { case "$1:$action" in restart:*) action=restart ;; reload:none) action=reload ;; esac; }

if [ -n "${APP_REPO:-}" ] && { [ -z "$only" ] || [ "$only" = app ]; }; then
    use_key "${name}-app"
    r="$(sync_repo "$APP_REPO" "${APP_BRANCH:-main}" "$appdir/repo" false)"; log "$name app: $r (key: ${gitkey:-none})"
    write_state app "$appdir/repo" "$r" false
    case "$r" in changed*|cloned*) want "${APP_ON_APP_CHANGE:-restart}"; changed+=(app) ;; failed) rc=1 ;; esac
fi
for ((j=0; j<${APP_DATA_COUNT:-0}; j++)); do
    dn="APP_DATA_${j}_NAME"; dr="APP_DATA_${j}_REPO"; db="APP_DATA_${j}_BRANCH"; dl="APP_DATA_${j}_LFS"; da="APP_DATA_${j}_ON_CHANGE"
    dname="${!dn}"; [ -z "$only" ] || [ "$only" = "$dname" ] || continue
    use_key "${name}-${dname}"
    r="$(sync_repo "${!dr}" "${!db:-main}" "$appdir/repos/$dname" "${!dl:-false}")"; log "$name $dname: $r (key: ${gitkey:-none})"
    write_state "$dname" "$appdir/repos/$dname" "$r" "${!dl:-false}"
    case "$r" in changed*) want "${!da:-reload}"; changed+=("$dname") ;; failed) rc=1 ;; esac
done
# cloned data repos need no action: the first render happens before the app starts
case "$action" in
    restart) systemctl try-restart "kiosk-static@${name}.service" && log "$name: restarted (${changed[*]} changed)" ;;
    reload)  reload_window && log "$name: page reloaded (${changed[*]} changed)" ;;
esac
if [ "$rc" = 1 ]; then
    urls="${APP_REPO:-}"; for ((j=0; j<${APP_DATA_COUNT:-0}; j++)); do dr="APP_DATA_${j}_REPO"; urls="$urls ${!dr}"; done
    [[ "$urls" == *"git@"* || "$urls" == *"ssh://"* ]] && warn "ssh clone failed: generate keys with 'kioskctl secrets git-key ${name}-app' / '${name}-<data name>' and add them as deploy keys"
fi
exit $rc
