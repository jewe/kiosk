#!/usr/bin/env bash
# Plymouth boot splash from a background image, quiet GRUB.
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
LOG_TAG="branding"
require_root

apt_install plymouth plymouth-themes
img="$(cfg '.display.background' "${KIOSK_SYS}/branding/backgrounds/black.jpg")"
[ -f "$img" ] || img="${KIOSK_SYS}/branding/backgrounds/black.jpg"

theme=/usr/share/plymouth/themes/kiosk
mkdir -p "$theme"
if [[ "$img" == *.png ]]; then
    cp -f "$img" "$theme/background.png"
else
    apt_install imagemagick
    convert "$img" "$theme/background.png"
fi

write_file "$theme/kiosk.plymouth" <<EOT || true
[Plymouth Theme]
Name=Kiosk
Description=Kiosk boot splash
ModuleName=script

[script]
ImageDir=$theme
ScriptFile=$theme/kiosk.script
EOT
write_file "$theme/kiosk.script" <<'EOT' || true
Window.SetBackgroundTopColor(0, 0, 0);
Window.SetBackgroundBottomColor(0, 0, 0);
img = Image("background.png");
sw = Window.GetWidth(); sh = Window.GetHeight();
scale = Math.Max(sw / img.GetWidth(), sh / img.GetHeight());
img = img.Scale(img.GetWidth() * scale, img.GetHeight() * scale);
sprite = Sprite(img);
sprite.SetPosition((sw - img.GetWidth()) / 2, (sh - img.GetHeight()) / 2, -10);
fun refresh() {}
Plymouth.SetRefreshFunction(refresh);
EOT

update-alternatives --install /usr/share/plymouth/themes/default.plymouth default.plymouth "$theme/kiosk.plymouth" 100 >/dev/null
update-alternatives --set default.plymouth "$theme/kiosk.plymouth" >/dev/null

if ! grep -q 'splash' /etc/default/grub; then
    sed -i 's/^GRUB_CMDLINE_LINUX_DEFAULT=.*/GRUB_CMDLINE_LINUX_DEFAULT="quiet splash loglevel=3 vt.global_cursor_default=0"/' /etc/default/grub
    grep -q '^GRUB_TIMEOUT=' /etc/default/grub && sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=1/' /etc/default/grub
    update-grub
fi
update-initramfs -u
log "boot splash set from $img"
