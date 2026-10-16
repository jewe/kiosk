#!/usr/bin/env bash
# Boot splash: delegates to branding/install.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
bash "${KIOSK_SYS}/branding/install.sh"
