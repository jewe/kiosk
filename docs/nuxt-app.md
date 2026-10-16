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

## Data repo

Plain files: `menu.json`, `images/…`. Edited by anyone with access to the repo, on GitHub directly or with a desktop client. Keep images at display size (a 4K image for a 300 px tile costs decode time on every reload). Optional `data_subdir` serves only one folder of the repo.

## Kiosk configuration

```yaml
apps:
  - name: menu
    type: static
    repo: git@github.com:you/menu-app.git
    branch: build
    data_repo: git@github.com:you/menu-data.git
    data_branch: main
    update_on_boot: true
    update_interval: 15m
    on_app_change: restart
    on_data_change: reload
    port: 8080
```

Private repos: GitHub accepts a deploy key on **one** repository only, so the kiosk uses one key per repo, named after the app and its role:

```sh
sudo kioskctl secrets git-key menu-app     # add to the app repo:  Settings → Deploy keys (read-only)
sudo kioskctl secrets git-key menu-data    # add to the data repo
sudo kioskctl apply
```

With the GitHub CLI on your machine: `gh repo deploy-key add key.pub -R you/menu-app -t kiosk-01`. For a fleet, a machine user with read access to both repos and one key per kiosk in that user's SSH keys avoids two keys per device; then `kioskctl secrets git-key` without a label is the shared fallback key. `kioskctl app update menu` pulls immediately, `kioskctl app logs menu` and `journalctl -u kiosk-content-update@menu` show what happened.

Persistence: content pulled while the kiosk runs in `locked` mode lives in RAM and is pulled again after a reboot. Devices whose content changes should run in `data` mode (`sudo kioskctl mount data`), where `/opt/kiosk` persists.

## Local development

```sh
cd menu-app
ln -s ../menu-data public/data     # /data/... works in `nuxt dev` exactly like on the kiosk
npm run dev
```
