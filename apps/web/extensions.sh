#!/usr/bin/env bash
# Chrome extensions from chrome.extensions in kiosk.yaml, force-installed by policy from a local server.
#   - name: <folder>   private extension: source /opt/kiosk/extensions/src/<folder>, key secrets/extensions/<folder>.pem
#   - id: <32 chars>   Web Store extension: downloaded once as .crx, then served locally (works offline)
# Every extension is published as /opt/kiosk/extensions/pub/<id>/{<id>.crx,update.xml}, served by nginx on
# http://127.0.0.1:8090/, and listed in /etc/opt/chrome/policies/managed/kiosk-extensions.json.
#   extensions.sh apply            (kioskctl apply)
#   extensions.sh list
#   extensions.sh update [id]      re-download Web Store entries
#   extensions.sh id <name>        print the ID of a private extension
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="extensions"
EXT_DIR="${KIOSK_DIR}/extensions"; SRC="${EXT_DIR}/src"; PUB="${EXT_DIR}/pub"
KEYS="${KIOSK_SECRETS}/extensions"
POLICY=/etc/opt/chrome/policies/managed/kiosk-extensions.json
BASE="http://127.0.0.1:8090"
cmd="${1:-apply}"

ext_id_from_key() { openssl rsa -in "$1" -pubout -outform DER 2>/dev/null | sha256sum | head -c 32 | tr '0-9a-f' 'a-p'; }
crx_version()     { unzip -p "$1" manifest.json 2>/dev/null | jq -r '.version // empty'; }
chrome_version()  { google-chrome-stable --version 2>/dev/null | grep -o '[0-9][0-9.]*' | head -1; }

publish() {   # publish <id> <crx> <version>
    local id="$1" crx="$2" ver="$3"
    mkdir -p "$PUB/$id"
    cmp -s "$crx" "$PUB/$id/$id.crx" || install -m 0644 "$crx" "$PUB/$id/$id.crx"
    write_file "$PUB/$id/update.xml" 0644 <<XML || true
<?xml version='1.0' encoding='UTF-8'?>
<gupdate xmlns='http://www.google.com/update2/response' protocol='2.0'>
  <app appid='${id}'><updatecheck codebase='${BASE}/${id}/${id}.crx' version='${ver}'/></app>
</gupdate>
XML
}

pack_private() {   # pack_private <name> → sets EXT_ID, or returns 1
    local name="$1" src="$SRC/$name" key="$KEYS/$name.pem" id crx ver tmp
    [[ "$name" =~ ^[a-z0-9_-]+$ ]] || { warn "extension name '$name' must be [a-z0-9_-]"; return 1; }
    [ -f "$src/manifest.json" ] || { warn "extension '$name': no $src/manifest.json"; return 1; }
    if [ ! -f "$key" ]; then
        install -d -m 0700 "$KEYS"; openssl genrsa -out "$key" 2048 2>/dev/null && chmod 0600 "$key" && log "key for '$name' generated: $key (keep it, it defines the extension ID)"
    fi
    id="$(ext_id_from_key "$key")"; [ ${#id} -eq 32 ] || { warn "extension '$name': cannot read key $key"; return 1; }
    ver="$(jq -r '.version // empty' "$src/manifest.json")"; [ -n "$ver" ] || { warn "extension '$name': no version in manifest.json"; return 1; }
    crx="$PUB/$id/$id.crx"
    if [ ! -f "$crx" ] || [ -n "$(find "$src" -newer "$crx" -print -quit)" ] || [ "$(crx_version "$crx")" != "$ver" ]; then
        tmp="$(mktemp -d /run/kiosk-pack.XXXXXX)"; cp -a "$src" "$tmp/$name"; cp "$key" "$tmp/key.pem"; chown -R "$KIOSK_USER" "$tmp"
        # Chrome packs without a window; HOME/user-data-dir on the temp dir keep the kiosk profile untouched
        sudo -u "$KIOSK_USER" env -i HOME="$tmp" google-chrome-stable --headless=new --no-sandbox --user-data-dir="$tmp/profile" \
            --pack-extension="$tmp/$name" --pack-extension-key="$tmp/key.pem" >/dev/null 2>&1
        if [ -f "$tmp/$name.crx" ]; then publish "$id" "$tmp/$name.crx" "$ver"; log "'$name' packed: $id version $ver"
        else rm -rf "$tmp"; warn "extension '$name': packing failed (google-chrome --pack-extension)"; return 1; fi
        rm -rf "$tmp"
    fi
    EXT_ID="$id"
}

fetch_store() {   # fetch_store <id> [force] → 0 if a crx is published
    local id="$1" force="${2:-}" crx="$PUB/$id/$id.crx" tmp ver
    [[ "$id" =~ ^[a-p]{32}$ ]] || { warn "'$id' is not an extension ID (32 letters a-p)"; return 1; }
    if [ -f "$crx" ] && [ -z "$force" ]; then return 0; fi
    tmp="$(mktemp)"
    if curl -fsSL --max-time 60 -o "$tmp" \
        "https://clients2.google.com/service/update2/crx?response=redirect&prodversion=$(chrome_version)&acceptformat=crx3&x=id%3D${id}%26uc" \
        && [ "$(head -c 4 "$tmp")" = "Cr24" ]; then
        ver="$(crx_version "$tmp")"; publish "$id" "$tmp" "${ver:-0}"; rm -f "$tmp"; log "$id downloaded from the Web Store: version ${ver:-?}"
    else
        rm -f "$tmp"
        if [ -f "$crx" ]; then warn "$id: download failed, keeping version $(crx_version "$crx")"; return 0; fi
        warn "$id: download failed (offline?) and no cached copy"; return 1
    fi
}

ensure_nginx() {
    command -v nginx >/dev/null || apt_install nginx
    rm -f /etc/nginx/sites-enabled/default
    write_file /etc/nginx/sites-available/kiosk-extensions.conf <<NGX || true
# Chrome extensions, force-installed by policy (apps/web/extensions.sh)
server {
    listen 127.0.0.1:8090;
    root ${PUB};
    access_log off;
    types { application/x-chrome-extension crx; text/xml xml; }
    add_header Cache-Control no-cache;
}
NGX
    ln -sfn /etc/nginx/sites-available/kiosk-extensions.conf /etc/nginx/sites-enabled/kiosk-extensions.conf
    systemctl enable nginx >/dev/null 2>&1
    nginx -t >/dev/null 2>&1 && systemctl reload-or-restart nginx || warn "nginx config test failed"
}

apply() {
    local n i name id ids=() ok=0
    mkdir -p "$SRC" "$PUB"; chown "$KIOSK_USER:$KIOSK_USER" "$SRC"
    n="$(cfg '.chrome.extensions | length' 0)"
    [ "$n" -gt 0 ] && ensure_nginx
    for ((i=0; i<n; i++)); do
        name="$(cfg ".chrome.extensions[$i].name")"; id="$(cfg ".chrome.extensions[$i].id")"
        if [ -n "$name" ]; then EXT_ID=""; pack_private "$name" || continue; id="$EXT_ID"
        elif [ -n "$id" ]; then fetch_store "$id" || continue
        else warn "chrome.extensions[$i]: needs name or id"; continue; fi
        ids+=("$id")
    done
    # policy
    if [ ${#ids[@]} -gt 0 ]; then
        mkdir -p "$(dirname "$POLICY")"
        printf '%s\n' "${ids[@]}" | jq -R . | jq -s --arg base "$BASE" '
            { ExtensionInstallForcelist: map("\(.);\($base)/\(.)/update.xml"),
              ExtensionSettings: (map({key: ., value: {installation_mode: "force_installed", update_url: "\($base)/\(.)/update.xml", override_update_url: true}}) | from_entries) }' \
            | write_file "$POLICY" 0644 && log "policy written: ${#ids[@]} extension(s)"
    else
        [ -f "$POLICY" ] && rm -f "$POLICY" && log "no extensions configured, policy removed"
    fi
    # drop published extensions that are no longer configured
    for d in "$PUB"/*/; do
        [ -d "$d" ] || continue; id="$(basename "$d")"
        [[ " ${ids[*]:-} " == *" $id "* ]] || { rm -rf "$d"; log "removed $id"; }
    done
    return 0
}

list() {
    local d id ver src served
    printf '%-34s %-10s %-8s %s\n' id version served source
    for d in "$PUB"/*/; do
        [ -d "$d" ] || continue; id="$(basename "$d")"; ver="$(crx_version "$d/$id.crx")"
        src="webstore"; for k in "$KEYS"/*.pem; do [ -f "$k" ] && [ "$(ext_id_from_key "$k")" = "$id" ] && src="$(basename "$k" .pem) (private)"; done
        served="no"; curl -fsI --max-time 2 "$BASE/$id/update.xml" >/dev/null 2>&1 && served="yes"
        printf '%-34s %-10s %-8s %s\n' "$id" "${ver:-?}" "$served" "$src"
    done
    [ -f "$POLICY" ] && echo "policy: $(jq -r '.ExtensionInstallForcelist | length' "$POLICY") forced in $POLICY" || echo "policy: none"
}

case "$cmd" in
    apply)  require_root; apply ;;
    list)   list ;;
    update) require_root; n="$(cfg '.chrome.extensions | length' 0)"
            for ((i=0; i<n; i++)); do id="$(cfg ".chrome.extensions[$i].id")"; [ -n "$id" ] || continue
                [ -z "${2:-}" ] || [ "$2" = "$id" ] || continue; fetch_store "$id" force; done
            log "update done; restart the apps to load new versions (kioskctl apply)" ;;
    id)     [ -f "$KEYS/${2:-}.pem" ] || die "no key for '${2:-}' (apply first)"; ext_id_from_key "$KEYS/$2.pem"; echo ;;
    *)      sed -n '2,11p' "$0"; exit 2 ;;
esac
