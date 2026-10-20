#!/usr/bin/env bash
# chrome_flags <name> <profile-dir>  → fills the array CHROME_ARGS with the kiosk's Chrome flags.
# Used by apps/web/launch.sh and tests/bench.sh, so benchmarks run with the production flags.
#
# Sources of extra flags, in order (later wins for simple flags):
#   /opt/kiosk/state/chrome.env   CHROME_GPU=auto|software, CHROME_FLAGS="..."   (config: chrome.gpu / chrome.flags)
#   APP_EXTRA_FLAGS               per app (config: apps[].extra_flags)
#   CHROME_EXTRA_FLAGS            environment, used by `bench.sh ab`
# --enable-features= / --disable-features= from all sources are merged into one flag each
# (Chrome only honours the last occurrence of these two flags).
chrome_flags() {
    local name="$1" profile="$2" f x
    local -a enable=(VaapiVideoDecodeLinuxGL VaapiIgnoreDriverChecks CanvasOopRasterization)
    local -a disable=(TranslateUI Translate MediaRouter OptimizationHints)
    [ -f /opt/kiosk/state/chrome.env ] && source /opt/kiosk/state/chrome.env
    CHROME_ARGS=(
        --user-data-dir="$profile"
        --class="kiosk-${name}"
        --no-first-run --no-default-browser-check
        --noerrdialogs --disable-infobars --disable-session-crashed-bubble
        --autoplay-policy=no-user-gesture-required
        --password-store=basic
        --check-for-update-interval=31536000
        --overscroll-history-navigation=0
        --disable-pinch
        --touch-events=enabled
        --ozone-platform=x11
        --force-device-scale-factor=1
        # rendering: raster on the GPU, shared buffers, no throttling of covered windows
        --enable-gpu-rasterization
        --enable-zero-copy
        --enable-native-gpu-memory-buffers
        --disable-renderer-backgrounding
        --disable-background-timer-throttling
        --disable-backgrounding-occluded-windows
        # no background work: a kiosk is never signed in and never updates itself
        --disable-background-networking
        --disable-component-update
        --disable-sync
        --disable-breakpad
        --metrics-recording-only
    )
    case "${CHROME_GPU:-auto}" in
        software) CHROME_ARGS+=(--disable-gpu) ;;
        *)        CHROME_ARGS+=(--ignore-gpu-blocklist) ;;
    esac
    # shellcheck disable=SC2206
    for f in ${CHROME_FLAGS:-} ${APP_EXTRA_FLAGS:-} ${CHROME_EXTRA_FLAGS:-}; do
        case "$f" in
            --enable-features=*)  IFS=, read -ra x <<<"${f#*=}"; enable+=("${x[@]}") ;;
            --disable-features=*) IFS=, read -ra x <<<"${f#*=}"; disable+=("${x[@]}") ;;
            *) CHROME_ARGS+=("$f") ;;
        esac
    done
    CHROME_ARGS+=(--enable-features="$(IFS=,; echo "${enable[*]}")" --disable-features="$(IFS=,; echo "${disable[*]}")")
}
