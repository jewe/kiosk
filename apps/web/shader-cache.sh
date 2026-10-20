#!/usr/bin/env bash
# shader-cache.sh restore|save <name> <profile-dir>
# The Chrome profile lives on tmpfs, so compiled GPU shaders would be lost at every start.
# They are kept in /opt/kiosk/state/chrome/<name> (a few MB) and copied in before start, out after stop.
set -uo pipefail
op="${1:?restore|save}"; name="${2:?name}"; profile="${3:?profile}"
keep="/opt/kiosk/state/chrome/${name}"
dirs=(GrShaderCache ShaderCache GraphiteDawnCache Default/GPUCache)
max_kb=51200
case "$op" in
    restore)
        [ -d "$keep" ] || exit 0
        for d in "${dirs[@]}"; do
            [ -d "$keep/$d" ] || continue
            mkdir -p "$profile/$(dirname "$d")" && cp -a "$keep/$d" "$profile/$d" 2>/dev/null || true
        done ;;
    save)
        [ -d "$profile" ] || exit 0
        mkdir -p "$keep" 2>/dev/null || exit 0
        for d in "${dirs[@]}"; do
            [ -d "$profile/$d" ] || continue
            [ "$(du -sk "$profile/$d" | cut -f1)" -le "$max_kb" ] || continue
            rm -rf "$keep/$d" && mkdir -p "$keep/$(dirname "$d")" && cp -a "$profile/$d" "$keep/$d" 2>/dev/null || true
        done ;;
esac
exit 0
