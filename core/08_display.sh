#!/usr/bin/env bash
# Display stack: delegates to display/install.sh
set -euo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../lib/common.sh"
bash "${KIOSK_SYS}/display/install.sh"
