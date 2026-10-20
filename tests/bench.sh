#!/usr/bin/env bash
# re-exec with bash when started with sh
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
# Benchmarks. Results go to /opt/kiosk/data/bench/ and the journal (tag kiosk-bench).
#   bench.sh gpu          glmark2 (windowed, ~2 min)
#   bench.sh motionmark   opens MotionMark in a Chrome window for 5 minutes; read the score on screen
#   bench.sh info         GPU, driver, video decode capabilities
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="bench"
what="${1:-info}"
export DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority"
out="${KIOSK_DIR}/data/bench"; mkdir -p "$out"; ts="$(date +%Y%m%d-%H%M%S)"
xk() { if [ "$(id -u)" -eq 0 ]; then sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="$XAUTHORITY" "$@"; else "$@"; fi; }
[ "$(id -u)" -eq 0 ] || [ "$(id -un)" = "$KIOSK_USER" ] || die "run as root: sudo kioskctl bench $what"

case "$what" in
    info)
        { echo "== GPU"; lspci -nn | grep -i 'vga\|3d\|display'
          echo "== renderer"; xk glxinfo -B 2>/dev/null | grep -i 'renderer\|OpenGL version\|Accelerated'
          echo "== vaapi"; xk vainfo 2>/dev/null | grep -i 'driver version\|VAProfileH264Main\|HEVCMain\b\|VP9Profile0\|AV1Profile0' | head -6
          echo "== xorg driver"; grep -o 'Loading.*/\(modesetting\|intel\|amdgpu\|nvidia\)_drv.so' /var/log/Xorg.0.log 2>/dev/null | tail -1
          echo "== tearing"; grep -i 'TearFree\|CompositionPipeline' /var/log/Xorg.0.log 2>/dev/null | head -3
        } | tee "$out/info-$ts.txt" ;;
    gpu)
        command -v glmark2 >/dev/null || apt_install glmark2
        log "glmark2 running (about 2 minutes)"
        xk stdbuf -oL glmark2 --fullscreen --annotate 2>&1 | tee "$out/glmark2-$ts.txt" | grep -i 'glmark2 Score\|GL_RENDERER\|error'
        score="$(grep -o 'glmark2 Score: [0-9]*' "$out/glmark2-$ts.txt" | awk '{print $3}')"
        logger -t kiosk-bench -- "{\"test\":\"glmark2\",\"score\":${score:-null},\"file\":\"$out/glmark2-$ts.txt\"}"
        log "glmark2 score: ${score:-?}" ;;
    motionmark)
        log "opening MotionMark for 5 minutes; the score is shown on screen at the end"
        xk timeout 300 google-chrome-stable --user-data-dir=/tmp/kiosk-bench --no-first-run --kiosk --window-position=0,0 \
            'https://browserbench.org/MotionMark1.3/' >/dev/null 2>&1 || true
        rm -rf /tmp/kiosk-bench ;;
    *) echo "usage: bench.sh info|gpu|motionmark" >&2; exit 2 ;;
esac
