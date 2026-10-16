#!/usr/bin/env bash
# Chrome pointed at the local nginx site of this instance.
set -euo pipefail
export APP_URL="http://127.0.0.1:${APP_PORT:-8080}/"
exec /opt/kiosksystem/apps/web/launch.sh "$1"
