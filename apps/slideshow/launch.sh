#!/usr/bin/env bash
# Slideshow = video launcher with image duration and no audio. Env: APP_PATH (directory), APP_INTERVAL (10)
set -euo pipefail
export APP_INTERVAL="${APP_INTERVAL:-10}"
export APP_AUDIO=false
exec /opt/kiosksystem/apps/video/launch.sh "$1"
