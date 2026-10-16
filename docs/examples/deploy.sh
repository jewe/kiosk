#!/usr/bin/env bash
# Run in the Nuxt app repo on your machine: builds the site and pushes .output/public
# to the "build" branch, which the kiosks clone. Requires a clean working tree.
set -euo pipefail
branch="${1:-build}"
npm run generate
git fetch -q origin "$branch" 2>/dev/null || true
tmp="$(mktemp -d)"
git worktree add -q -B "$branch" "$tmp" "origin/$branch" 2>/dev/null || git worktree add -q --orphan -b "$branch" "$tmp"
rsync -a --delete --exclude .git .output/public/ "$tmp/"
git -C "$tmp" add -A
git -C "$tmp" commit -q -m "build $(git rev-parse --short HEAD) $(date +%Y-%m-%d\ %H:%M)" || echo "nothing changed"
git -C "$tmp" push -q origin "$branch"
git worktree remove --force "$tmp"
echo "pushed to $branch"
