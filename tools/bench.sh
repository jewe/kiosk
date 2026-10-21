#!/usr/bin/env bash
# Collect benchmark results from kiosks and render one table for all machines and setups.
#   tools/bench.sh pull <user@host>...        copy /opt/kiosk/data/bench/*.json into docs/benchmarks/<hostname>/
#   tools/bench.sh table                      render docs/benchmarks/README.md from all collected files
# docs/ is the private docs repo (jewe/kiosk-docs); commit there after pulling.
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
dir=docs/benchmarks
case "${1:-}" in
    pull)
        shift; [ $# -gt 0 ] || { sed -n '2,5p' "$0"; exit 1; }
        for host in "$@"; do
            name="$(ssh -o BatchMode=yes -o ConnectTimeout=8 "$host" hostname)" || { echo "$host: unreachable" >&2; continue; }
            mkdir -p "$dir/$name"
            n="$(ssh "$host" 'ls /opt/kiosk/data/bench/*.json 2>/dev/null | wc -l')"
            [ "$n" -gt 0 ] || { echo "$name: no results"; continue; }
            ssh "$host" 'tar -C /opt/kiosk/data/bench -czf - $(cd /opt/kiosk/data/bench && ls *.json)' | tar -C "$dir/$name" -xzf -
            echo "$name: $(ls "$dir/$name"/*.json | wc -l) result files"
        done
        "$0" table ;;
    table)
        [ -d "$dir" ] || { echo "no $dir yet (tools/bench.sh pull <host>)"; exit 1; }
        {
            echo "# Benchmark results"
            echo
            echo "Collected with \`tools/bench.sh pull\`, measured with \`kioskctl bench\`. Levers: Chrome flags, TearFree, GPU clock floor, low latency (see docs/performance.md)."
            echo
            echo "| Host | GPU | CPU | RAM | Chrome | Xorg | Test | Label | Flags | Score | Levers | Date |"
            echo "|---|---|---|---|---|---|---|---|---|---|---|---|"
            cat "$dir"/*/*.json | jq -r -s '
                def lev: .machine.levers // {} | [(.chrome_flags // [] | join(" ")), (if .tearfree == false then "no-tearfree" else empty end), (if .gpu_min_freq != "auto" and .gpu_min_freq != null then "gpu>=\(.gpu_min_freq)" else empty end), (if .low_latency == true then "low-latency" else empty end)] | map(select(length > 0)) | join(" ");
                sort_by([.machine.gpu // "", .machine.host // "", .test, .ts]) | .[] |
                "| \(.machine.host // "?") | \(.machine.gpu // "?" | .[0:40]) | \(.machine.cpu // "?" | .[0:32]) | \((.machine.ram_mb // 0) / 1024 | floor) GB | \(.machine.chrome // "-") | \(.machine.xorg_driver // "-") | \(.test) | \(.label // "-") | \(.extra_flags // "" | if . == "" then "-" else . end) | **\(.score // "-" | if type == "number" then (. * 10 | round / 10) else . end)** | \(lev | if . == "" then "-" else . end) | \(.ts | .[0:10]) |"'
            echo
            echo "Rows sorted by GPU, host, test, date. A/B runs share a date and differ in Flags."
        } > "$dir/README.md"
        echo "wrote $dir/README.md ($(grep -c '^| ' "$dir/README.md") lines)" ;;
    *) sed -n '2,5p' "$0"; exit 1 ;;
esac
