#!/usr/bin/env bash
# Run in the Nuxt app repo on your machine: builds the site and pushes .output/public
# to the "build" branch, which the kiosks clone. Requires a clean working tree.
set -euo pipefail
branch="${1:-build}"
npm run generate
git fetch -q origin "$branch" 2>/dev/null || true
tmp="$(mktemp -d)"
# works with git >= 2.20 (no `worktree add --orphan`): detach a worktree, then switch it to the build branch
git worktree add -q --detach "$tmp"
if git rev-parse -q --verify "origin/$branch" >/dev/null; then
    git -C "$tmp" checkout -q -B "$branch" "origin/$branch"
else
    git -C "$tmp" checkout -q --orphan "$branch"
    git -C "$tmp" rm -rfq --cached . 2>/dev/null || true
    find "$tmp" -mindepth 1 -maxdepth 1 ! -name .git -exec rm -rf {} +
fi
rsync -a --delete --exclude .git .output/public/ "$tmp/"
git -C "$tmp" add -A
git -C "$tmp" commit -q -m "build $(git rev-parse --short HEAD) $(date +%Y-%m-%d\ %H:%M)" || echo "nothing changed"
git -C "$tmp" push -q origin "$branch"
git worktree remove --force "$tmp"
git branch -q -D "$branch" 2>/dev/null || true   # the local branch is only needed inside the worktree
echo "pushed to $branch"
