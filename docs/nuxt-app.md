# Nuxt app on the kiosk: app repo + data repo

The kiosk serves a static Nuxt build with nginx on `127.0.0.1` and shows it in Chrome. The app code and the data (menu, texts, images) live in two git repos and are updated independently. A data change never needs a rebuild.

## Contract

| Where | What |
|---|---|
| `/` | the app: `nuxt generate` output (`.output/public`), SPA fallback to `index.html` |
| `/data/` | the data repo checkout, e.g. `/data/menu.json`, `/data/images/pizza.jpg`; served with `Cache-Control: no-cache`, so every reload shows the pulled state |
| reload | after a data change the kiosk reloads the page (`on_data_change: reload`); after an app change it restarts Chrome |
| offline | everything is local; the app must not load anything from the internet (fonts, scripts, APIs) |

In the app, fetch data **in the browser**, not at generate time, otherwise the menu is baked into the build:

```ts
// pages/index.vue
const { data: menu } = await useFetch('/data/menu.json', { server: false })
// images: <img :src="`/data/images/${item.image}`">
```

## App repo

Build locally and commit the output. Two layouts, both work with the same kiosk config:

1. **`build` branch** (recommended): `docs/examples/deploy.sh` from this repo, copied into the app repo, runs `npm run generate` and pushes `.output/public` to the `build` branch. Kiosk config: `branch: build`, `subdir: ""`.
2. **Folder in `main`**: copy `.output/public` to `dist/` and commit it. Kiosk config: `branch: main`, `subdir: dist`.

## Data repos

Plain files: `menu.json`, `images/…`. Edited by anyone with access to the repo, on GitHub directly or with a desktop client. Keep images at display size (a 4K image for a 300 px tile costs decode time on every reload). Optional `subdir` serves only one folder of the repo.

An app can have **up to five data repos**, each with its own URL prefix, deploy key, branch and change action. Split by who edits and how often: texts and menu in `data`, map tiles in `geodata`, videos in `videos`. The app fetches them under their URLs (`/data/menu.json`, `/geodata/tiles/…`, `/videos/clip.mp4`); nginx serves every data URL with `Cache-Control: no-cache`, so a reload shows the pulled state.

## Large files

- Plain git with the kiosk's shallow clone is fine up to a few hundred MB per repo. The kiosk keeps only the latest commit on disk (shallow fetch, then `git gc` once the object store exceeds 50 MB). The *server side* keeps the whole history, so a repo with replaced videos grows without bound on GitHub; keep videos in their own repo so the app and data repos stay small.
- **Git LFS** (`lfs: true`) keeps the git history small and the kiosk pulls only the LFS objects of the current commit, then prunes the local LFS cache. Needs `git lfs track "*.mp4"` in the repo (and `git-lfs` on the editing machines). GitHub's free LFS quota is 1 GB storage and 1 GB bandwidth per month per account, and every kiosk pull counts: ten kiosks pulling a 500 MB repo exceed it at the first update. LFS on a self-hosted Gitea or GitLab has no such quota. Rule of thumb: LFS above about 200 MB per repo, self-hosted when there are several kiosks. A repo that uses LFS without `lfs: true` on the kiosk gets pointer stubs instead of files; the update log warns about it.
- `on_change: none` for media repos: `<video>` and `<img>` sources are fetched again when they are shown next, no page reload needed.

`kioskctl status` lists every repo of an app with commit, age, size and whether the last sync failed; `kioskctl app update menu videos` pulls one repo now.

## Kiosk configuration

```yaml
apps:
  - name: menu
    type: static
    repo: git@github.com:you/menu-app.git
    branch: build
    data:
      - name: data                     # served under /data, key secrets/git/menu-data
        repo: git@github.com:you/menu-data.git
        branch: main
        on_change: reload
      - name: geodata                  # served under /geodata, key secrets/git/menu-geodata
        repo: git@github.com:you/menu-geodata.git
      - name: videos
        repo: git@github.com:you/menu-videos.git
        lfs: true
        on_change: none
    update_on_boot: true
    update_interval: 15m
    on_app_change: restart
    port: 8080
```

The older single-repo keys `data_repo`, `data_branch`, `data_subdir`, `data_url`, `on_data_change` still work and mean one entry named `data`.

Private repos: GitHub accepts a deploy key on **one** repository only, so the kiosk uses one key per repo, named after the app and its role:

```sh
sudo kioskctl secrets git-key menu-app     # add to the app repo:  Settings → Deploy keys (read-only)
sudo kioskctl secrets git-key menu-data    # add to the data repo; one key per data repo: menu-geodata, menu-videos
sudo kioskctl apply
```

`tools/secrets.sh pull kiosk-01 kioskadmin@<ip>` keeps a copy of the generated keys on your machine. With the GitHub CLI: `gh repo deploy-key add key.pub -R you/menu-app -t kiosk-01`. For a fleet, a machine user with read access to both repos and one key per kiosk in that user's SSH keys avoids two keys per device; then `kioskctl secrets git-key` without a label is the shared fallback key. `kioskctl app update menu` pulls immediately, `kioskctl app logs menu` and `journalctl -u kiosk-content-update@menu` show what happened.

Persistence: content pulled while the kiosk runs in `locked` mode lives in RAM and is pulled again after a reboot. Devices whose content changes should run in `data` mode (`sudo kioskctl mount data`), where `/opt/kiosk` persists.

## Local development

```sh
cd menu-app
ln -s ../menu-data public/data     # /data/... works in `nuxt dev` exactly like on the kiosk
npm run dev
```
