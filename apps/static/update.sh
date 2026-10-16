#!/usr/bin/env bash
# Clone or pull the content repo of a static app. Restarts the app when the content changed.
#   update.sh <name>     (also run by kiosk-content-update@<name>.service at boot)
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="app:static"
name="${1:?name}"
set -a; source "${KIOSK_STATE}/apps/${name}.env"; set +a
[ -n "${APP_REPO:-}" ] || { log "$name has no repo configured"; exit 0; }

repo="${KIOSK_DIR}/apps/${name}/repo"
branch="${APP_BRANCH:-main}"
git_as() { sudo -u "$KIOSK_USER" timeout 120 git "$@"; }

if [ -d "$repo/.git" ]; then
    before="$(git -C "$repo" rev-parse HEAD)"
    git_as -C "$repo" fetch -q --depth 1 origin "$branch"
    git_as -C "$repo" reset -q --hard FETCH_HEAD
    after="$(git -C "$repo" rev-parse HEAD)"
    if [ "$before" != "$after" ]; then
        log "$name updated ${before:0:7} -> ${after:0:7}"
        systemctl try-restart "kiosk-static@${name}.service" || true
    else
        log "$name unchanged (${after:0:7})"
    fi
else
    install -d -o "$KIOSK_USER" -g "$KIOSK_USER" "$(dirname "$repo")"
    git_as clone -q --depth 1 --branch "$branch" "$APP_REPO" "$repo"
    log "$name cloned $(git -C "$repo" rev-parse --short HEAD)"
fi
