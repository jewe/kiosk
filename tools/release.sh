#!/usr/bin/env bash
# Bump minor or major (patch bumps automatically on every commit via .githooks/pre-commit),
# commit, tag and push.   tools/release.sh minor|major
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
part="${1:-minor}"
IFS=. read -r a b c < VERSION
case "$part" in
    major) a=$((a+1)); b=0; c=0 ;;
    minor) b=$((b+1)); c=0 ;;
    *) echo "usage: release.sh minor|major" >&2; exit 1 ;;
esac
[ -z "$(git status --porcelain)" ] || { echo "working tree not clean" >&2; exit 1; }
v="$a.$b.$c"; echo "$v" > VERSION
git add VERSION && git commit -q -m "Release $v" && git tag -a "v$v" -m "Release $v" && git push -q origin main --tags
echo "released $v"
