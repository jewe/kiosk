# Chrome extensions

Extensions are force-installed through the Chrome policy `ExtensionInstallForcelist`. Branded Chrome ignores `--load-extension` since version 137, so this is the only supported way, and it works in kiosk mode. Every extension, private or from the Web Store, is served from the kiosk itself (`http://127.0.0.1:8090/`), because the Chrome profile lives on tmpfs and the extension is installed again at every start. No internet is needed at boot.

## Config

```yaml
chrome:
  extensions:
    - name: hello                            # private extension
    - id: cjpalhdlnbpafiamejdnhcphjbkeiagm   # Web Store extension
```

Apply with `sudo kioskctl apply`. The apps are restarted and Chrome picks the policy up at start.

## Private extension (`name`)

- Source: an unpacked extension folder with `manifest.json` (manifest V3) in `/opt/kiosk/extensions/src/<name>/`. Copy it there with scp, or keep it in a git checkout. `docs/examples/extension-hello/` is a two-file example (red border on every page).
- Key: `/opt/kiosk/secrets/extensions/<name>.pem`, generated on the first apply. The extension ID is derived from this key, so keep it: `tools/secrets.sh pull` copies it to the repo's git-ignored `secrets/` folder, `push` restores it on a new device. A new key means a new ID.
- Packing: apply packs the folder with `google-chrome --pack-extension` (headless, as the kiosk user) whenever a source file is newer than the published `.crx` or the manifest version changed. Bump `version` in the manifest for every change, Chrome only updates on a higher version.
- `kioskctl extension id <name>` prints the ID.

## Web Store extension (`id`)

The 32-letter ID from the Web Store URL. On the first apply the `.crx` is downloaded from Google's update service (needs internet once) and kept in `/opt/kiosk/extensions/pub/<id>/`. `sudo kioskctl extension update [id]` downloads the current version again. Without internet and without a cached copy the entry is skipped with a warning.

## How it works

- `/opt/kiosk/extensions/pub/<id>/<id>.crx` and `update.xml` are served by nginx on `127.0.0.1:8090` with the content type `application/x-chrome-extension`.
- `/etc/opt/chrome/policies/managed/kiosk-extensions.json` lists every ID in `ExtensionInstallForcelist` with the local update URL, and sets `override_update_url` in `ExtensionSettings` so Chrome never looks at the manifest's own update URL.
- Entries removed from the config are removed from the policy and from `pub/` at the next apply. The policy file disappears when the list is empty.
- The forced install is asynchronous: for about a second after Chrome starts the page runs without the extension. A page that depends on the extension should wait for it (for example a message from the content script) instead of assuming it at load time.
- Persistence: `pub/` and the keys live under `/opt/kiosk`, so they survive reboots in `data` mode. In `locked` mode they are rebuilt from the sources at every apply after boot; without internet a Web Store entry is then missing until the next `rw`/`data` apply.

## Check

- `kioskctl extension list`: ID, version, whether nginx serves it, source.
- `kioskctl doctor` fails when a forced extension is not served.
- In dev mode (`kioskctl devmode on`, Ctrl+Alt+T) a second Chrome window can open `chrome://policy` and `chrome://extensions`.
- Logs: `journalctl -t extensions`, and the app logs (`kioskctl app logs <name>`) show policy errors from Chrome.
