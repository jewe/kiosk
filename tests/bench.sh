#!/usr/bin/env bash
# Benchmarks. Results: /opt/kiosk/data/bench/ and the journal (tag kiosk-bench, see kioskctl history).
#   bench.sh info                  GPU, driver, video decode, Chrome's own GPU feature status
#   bench.sh gpu                   glmark2 (fullscreen, about 8 minutes)
#   bench.sh motionmark [--online] MotionMark with the production Chrome flags, score read via DevTools (about 6 minutes)
#   bench.sh ab "<flags A>" "<flags B>" [rounds]   MotionMark alternating with two extra flag sets (default 2 rounds each)
# The kiosk apps are stopped during gpu/motionmark and started again afterwards.
[ -n "${BASH_VERSION:-}" ] || exec bash "$0" "$@"
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
source "${KIOSK_SYS}/apps/web/chrome-flags.sh"
LOG_TAG="bench"
what="${1:-info}"
export DISPLAY=:0 XAUTHORITY="/home/${KIOSK_USER}/.Xauthority"
out="${KIOSK_DIR}/data/bench"; mkdir -p "$out"; ts="$(date +%Y%m%d-%H%M%S)"
CDP="${KIOSK_SYS}/tests/cdp.py"; PORT=9222
MM_DIR="${KIOSK_DIR}/data/bench/MotionMark"; MM_PORT=8765
xk() { if [ "$(id -u)" -eq 0 ]; then sudo -u "$KIOSK_USER" env DISPLAY=:0 XAUTHORITY="$XAUTHORITY" "$@"; else "$@"; fi; }
[ "$(id -u)" -eq 0 ] || [ "$(id -un)" = "$KIOSK_USER" ] || die "run as root: sudo kioskctl bench $what"

apps_were_active=0
quiet_start() {
    if systemctl is-active kiosk.target >/dev/null 2>&1; then
        apps_were_active=1; systemctl stop 'kiosk-*@*.service' 2>/dev/null || true
    fi
}
quiet_end() { [ "$apps_were_active" = 1 ] && systemctl start kiosk.target 2>/dev/null || true; }
trap 'rm -f "$BENCH_POLICY"; quiet_end' EXIT

clocks() {   # one JSON object with governor, EPP, GPU clock, CPU temperature
    local gov epp gpu gmax temp
    gov="$(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null)"
    epp="$(cat /sys/devices/system/cpu/cpu0/cpufreq/energy_performance_preference 2>/dev/null)"
    gpu="$(cat /sys/class/drm/card*/gt_cur_freq_mhz 2>/dev/null | head -1)"
    gmax="$(cat /sys/class/drm/card*/gt_max_freq_mhz 2>/dev/null | head -1)"
    temp="$(sensors -j 2>/dev/null | jq -r '[.. | objects | to_entries[] | select(.key | test("^(Package id 0|Tctl|Tdie|Core 0|temp1)$")) | .value | objects | to_entries[] | select(.key | test("_input$")) | .value] | first // empty' 2>/dev/null)"
    jq -c -n --arg gov "$gov" --arg epp "$epp" --arg gpu "$gpu" --arg gmax "$gmax" --arg temp "$temp" \
        '{governor:$gov, epp:$epp, gpu_mhz:($gpu|tonumber? // null), gpu_max_mhz:($gmax|tonumber? // null), cpu_temp:($temp|tonumber? // null)}'
}

# machine: what this result was measured on, so a file is meaningful on its own
machine() {
    local cpu gpu ram xdrv chrome levers
    cpu="$(lscpu 2>/dev/null | awk -F: '/Model name/ {gsub(/^ +/,"",$2); print $2; exit}')"
    gpu="$(lspci -nn 2>/dev/null | grep -i 'vga\|3d\|display' | sed 's/^[^:]*: //; s/ (rev.*//; s/ \[[0-9a-f]\{4\}:[0-9a-f]\{4\}\]//' | paste -sd'+' -)"   # all GPUs, e.g. "Intel ... UHD 630+NVIDIA ... RTX 3060"
    ram="$(free -m | awk '/^Mem:/ {print $2}')"
    xdrv="$(grep -o 'Loading.*/\(modesetting\|intel\|amdgpu\|nvidia\)_drv.so' /var/log/Xorg.0.log 2>/dev/null | tail -1 | sed 's#.*/##; s/_drv.so//')"
    chrome="$(google-chrome-stable --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -1)"
    levers="$(yq -c '{chrome_flags:(.chrome.flags // []), tearfree:(.display.tearfree // true), gpu_min_freq:(.performance.gpu_min_freq // "auto"), low_latency:(.performance.low_latency // false)}' "$KIOSK_CONFIG" 2>/dev/null || echo '{}')"
    jq -c -n --arg host "$(hostname)" --arg cpu "$cpu" --arg gpu "$gpu" --argjson ram "${ram:-0}" --arg kernel "$(uname -r)" \
        --arg os "$(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-}")" --arg xdrv "$xdrv" --arg chrome "$chrome" \
        --arg system "$(cat "$KIOSK_SYS/VERSION" 2>/dev/null)" --argjson levers "$levers" \
        --arg screen "$(xk xrandr --query 2>/dev/null | awk '/ connected/ && /primary/ {print $4; exit}')" \
        '{host:$host, cpu:$cpu, gpu:$gpu, ram_mb:$ram, os:$os, kernel:$kernel, xorg_driver:$xdrv, chrome:$chrome, system:$system, screen:$screen, levers:$levers}'
}

# chrome_start <url> [extra flags...]   Chrome with the production flags + DevTools port, as the kiosk user.
# The kiosk policy disallows developer tools (DeveloperToolsAvailability=2), which also silences page-level
# DevTools commands; a temporary policy file allows them for the benchmark only.
BENCH_POLICY=/etc/opt/chrome/policies/managed/zz-bench.json
chrome_start() {
    local url="$1"; shift
    local profile=/run/kiosk/bench
    rm -rf "$profile"; mkdir -p "$profile"; chown "$KIOSK_USER:$KIOSK_USER" "$profile"
    mkdir -p "$(dirname "$BENCH_POLICY")"; echo '{"DeveloperToolsAvailability": 1}' > "$BENCH_POLICY"
    CHROME_EXTRA_FLAGS="${CHROME_EXTRA_FLAGS:-} $*" chrome_flags bench "$profile"
    xk setsid google-chrome-stable "${CHROME_ARGS[@]}" --remote-debugging-port=$PORT --remote-allow-origins='*' \
        --window-position=0,0 --kiosk "$url" >/dev/null 2>&1 < /dev/null &
    CHROME_PID=$!
}
chrome_stop() { pkill -f "user-data-dir=/run/kiosk/bench" 2>/dev/null || true; sleep 1; rm -rf /run/kiosk/bench "$BENCH_POLICY"; }

# chrome_gpu_status: the feature list of chrome://gpu (hardware accelerated or not)
chrome_gpu_status() {
    chrome_start about:blank
    python3 "$CDP" $PORT nav chrome://gpu 2>/dev/null && sleep 2
    python3 "$CDP" $PORT eval '(function(){var r=[];function walk(n){if(n.shadowRoot)walk(n.shadowRoot);if(n.tagName==="LI"&&/:/.test(n.textContent))r.push(n.textContent.trim().replace(/\s+/g," "));for(var c of n.children||[])walk(c)}walk(document.body);return r.join("\n")})()' 2>/dev/null \
        | python3 -c 'import sys,json; s=json.load(sys.stdin) or ""; print("\n".join(l for l in s.splitlines() if any(k in l for k in ("Canvas","Rasterization","Video Decode","Video Encode","WebGL","Vulkan","OpenGL","Compositing","Skia","Graphite"))))' \
        || echo "(chrome://gpu could not be read)"
    chrome_stop
}

motionmark_url() {   # offline copy if present, else browserbench.org
    if [ "${1:-}" != "--online" ]; then
        if [ ! -f "$MM_DIR/MotionMark/index.html" ]; then
            log "cloning MotionMark into $MM_DIR (once, about 30 MB)" >&2
            git clone -q --depth 1 https://github.com/WebKit/MotionMark "$MM_DIR" 2>/dev/null || warn "clone failed (offline?), using browserbench.org" >&2
        fi
        if [ -f "$MM_DIR/MotionMark/index.html" ]; then
            fuser -k ${MM_PORT}/tcp >/dev/null 2>&1 || true
            python3 -m http.server --bind 127.0.0.1 --directory "$MM_DIR" $MM_PORT >/dev/null 2>&1 &
            HTTP_PID=$!; sleep 1
            echo "http://127.0.0.1:${MM_PORT}/MotionMark/index.html"; return
        fi
    fi
    echo "https://browserbench.org/MotionMark1.3/"
}

# motionmark_run [label] [extra flags...]  → prints the score, writes JSON
motionmark_run() {
    local label="${1:-default}"; shift
    local url score tests before after f="$out/motionmark-$ts-$label.json"
    url="$(motionmark_url "${BENCH_ONLINE:-}")"
    before="$(clocks)"
    chrome_start "$url" "$@"
    python3 "$CDP" $PORT wait 'typeof benchmarkController !== "undefined" && document.readyState === "complete"' 90 >/dev/null || { warn "MotionMark page did not load ($url)"; chrome_stop; return 1; }
    sleep 3
    python3 "$CDP" $PORT eval 'benchmarkController.startBenchmark(); true' >/dev/null || { warn "could not start the benchmark"; chrome_stop; return 1; }
    score="$(python3 "$CDP" $PORT wait '(function(){var e=document.querySelector("#results .score");return e&&e.textContent.trim()?parseFloat(e.textContent):0})()' 900)" || { warn "no result after 15 minutes"; chrome_stop; return 1; }
    tests="$(python3 "$CDP" $PORT eval '(function(){var t=document.querySelector("#results-score");return t?Array.from(t.querySelectorAll("tr")).map(r=>Array.from(r.children).map(c=>c.textContent.trim()).join(":")).join("\n"):""})()' 2>/dev/null | python3 -c 'import sys,json;print(json.load(sys.stdin) or "")')"
    after="$(clocks)"
    chrome_stop
    jq -n --arg label "$label" --arg flags "$*" --argjson score "$score" --arg tests "$tests" --argjson before "$before" --argjson after "$after" --arg url "$url" --arg ts "$ts" --argjson machine "$(machine)" \
        '{test:"motionmark",label:$label,score:$score,extra_flags:$flags,url:$url,ts:$ts,machine:$machine,before:$before,after:$after,tests:($tests|split("\n")|map(select(length>0)))}' > "$f"
    logger -t kiosk-bench -- "$(jq -c '{test,label,score,extra_flags,file:"'"$f"'"}' "$f")"
    echo "$score"
}

case "$what" in
    info)
        {
          echo "== gpu";    lspci -nn 2>/dev/null | grep -i 'vga\|3d\|display'
          echo "== renderer"; xk glxinfo -B 2>/dev/null | grep -i 'renderer\|OpenGL version\|Accelerated' || echo "glxinfo failed (X not running?)"
          echo "== vaapi";  vainfo 2>/dev/null | grep -i 'driver\|VAProfile' | head -12 || echo "vainfo failed"
          echo "== xorg driver"; grep -o 'Loading.*/\(modesetting\|intel\|amdgpu\|nvidia\)_drv.so' /var/log/Xorg.0.log 2>/dev/null | tail -1
          echo "== tearing"; grep -i 'TearFree\|CompositionPipeline' /var/log/Xorg.0.log 2>/dev/null | head -3
          echo "== compositor"; pgrep -a 'picom|compton|xcompmgr' || echo "none (good)"
          echo "== clocks"; clocks
          echo "== chrome://gpu"; if x_running 2>/dev/null || xk xset q >/dev/null 2>&1; then quiet_start; chrome_gpu_status; else echo "X not running"; fi
        } | tee "$out/info-$ts.txt" ;;
    gpu)
        command -v glmark2 >/dev/null || apt_install glmark2
        quiet_start
        log "glmark2 running (about 8 minutes, fullscreen)"
        xk stdbuf -oL glmark2 --fullscreen --annotate 2>&1 | tee "$out/glmark2-$ts.txt" | grep -i 'glmark2 Score\|GL_RENDERER\|error'
        score="$(grep -o 'glmark2 Score: [0-9]*' "$out/glmark2-$ts.txt" | awk '{print $3}')"
        jq -n --argjson score "${score:-null}" --arg ts "$ts" --argjson machine "$(machine)" --argjson clocks "$(clocks)" \
            '{test:"glmark2", label:"default", score:$score, ts:$ts, machine:$machine, after:$clocks}' > "$out/glmark2-$ts.json"
        logger -t kiosk-bench -- "{\"test\":\"glmark2\",\"score\":${score:-null},\"file\":\"$out/glmark2-$ts.json\"}"
        log "glmark2 score: ${score:-?}" ;;
    motionmark)
        [ "${2:-}" = "--online" ] && BENCH_ONLINE=--online
        quiet_start
        log "MotionMark running (about 6 minutes); result in $out and the journal"
        s="$(motionmark_run default)" && log "MotionMark score: $s"
        [ -n "${HTTP_PID:-}" ] && kill "$HTTP_PID" 2>/dev/null ;;
    ab)
        a="${2:-}"; b="${3:?usage: bench.sh ab \"<flags A>\" \"<flags B>\" [rounds]}"; rounds="${4:-2}"
        quiet_start
        log "A/B: ${rounds} rounds each, alternating. A='${a:-(none)}'  B='$b'"
        sa=(); sb=()
        for ((r=1; r<=rounds; r++)); do
            # shellcheck disable=SC2086
            s="$(motionmark_run "A$r" $a)" && sa+=("$s") && log "A round $r: $s"
            # shellcheck disable=SC2086
            s="$(motionmark_run "B$r" $b)" && sb+=("$s") && log "B round $r: $s"
        done
        med() { printf '%s\n' "$@" | sort -n | awk '{a[NR]=$1} END {if (NR==0) print "?"; else if (NR%2) print a[(NR+1)/2]; else print (a[NR/2]+a[NR/2+1])/2}'; }
        log "A median: $(med "${sa[@]}")   B median: $(med "${sb[@]}")   (A: ${sa[*]:-} | B: ${sb[*]:-})"
        [ -n "${HTTP_PID:-}" ] && kill "$HTTP_PID" 2>/dev/null ;;
    *) echo "usage: bench.sh info|gpu|motionmark [--online]|ab \"<flags A>\" \"<flags B>\" [rounds]" >&2; exit 2 ;;
esac
