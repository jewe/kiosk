#!/usr/bin/env bash
# audio.sink / audio.volume via PipeWire (wpctl) in the kiosk user's session.
# Also run from xsession.sh at every session start.
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="audio"
uid="$(id -u "$KIOSK_USER" 2>/dev/null || echo 1001)"
# wpctl prints RTKit warnings on stderr when no rtkit daemon runs; they are harmless
wp() { if [ "$(id -u)" -eq 0 ]; then sudo -u "$KIOSK_USER" env XDG_RUNTIME_DIR="/run/user/$uid" wpctl "$@" 2>/dev/null; else XDG_RUNTIME_DIR="/run/user/$uid" wpctl "$@" 2>/dev/null; fi; }
command -v wpctl >/dev/null || { warn "wpctl missing"; exit 0; }
wp status >/dev/null 2>&1 || { warn "pipewire not running for $KIOSK_USER"; exit 0; }

sink="$(cfg '.audio.sink')"
if [ -n "$sink" ]; then
    id="$(wp status 2>/dev/null | sed -n '/Sinks:/,/Sources:/p' | grep -i -- "$sink" | head -1 | grep -o '[0-9]\+\.' | head -1 | tr -d .)"
    if [ -n "$id" ]; then wp set-default "$id" && log "default sink: $sink ($id)"; else warn "sink '$sink' not found"; fi
fi
vol="$(cfg '.audio.volume' 70)"
wp set-volume @DEFAULT_AUDIO_SINK@ "${vol}%" && wp set-mute @DEFAULT_AUDIO_SINK@ 0 && log "volume ${vol}%"
exit 0
