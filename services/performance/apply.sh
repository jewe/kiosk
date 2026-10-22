#!/usr/bin/env bash
# performance.*  and display.tearfree: CPU governor/EPP, Intel GPU clock floor, low-latency kernel options,
# i915 module options, TearFree in the Xorg config. Run by kioskctl apply and (with --boot) by kiosk-cpufreq.service.
#   performance.gpu_min_freq: auto | max | <MHz>     (Intel only)
#   performance.low_latency: false | true            (intel_idle.max_cstate=1 processor.max_cstate=1, GRUB drop-in)
#   display.tearfree: true | false                   (modesetting / amdgpu Option "TearFree")
set -uo pipefail
source "$(dirname "${BASH_SOURCE[0]}")/../../lib/common.sh"
LOG_TAG="performance"
boot_only=0; [ "${1:-}" = "--boot" ] && boot_only=1

# --- CPU: performance governor and energy preference (every boot) ---
for f in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do [ -w "$f" ] && echo performance > "$f" 2>/dev/null; done
for f in /sys/devices/system/cpu/cpu*/cpufreq/energy_performance_preference; do [ -w "$f" ] && echo performance > "$f" 2>/dev/null; done
[ -w /sys/devices/system/cpu/intel_pstate/no_turbo ] && echo 0 > /sys/devices/system/cpu/intel_pstate/no_turbo 2>/dev/null

# --- Intel GPU clock floor (every boot) ---
want="$(cfg '.performance.gpu_min_freq' auto)"
for card in /sys/class/drm/card*; do
    [ -w "$card/gt_min_freq_mhz" ] || continue
    rp0="$(cat "$card/gt_RP0_freq_mhz" 2>/dev/null)"; rpn="$(cat "$card/gt_RPn_freq_mhz" 2>/dev/null)"
    case "$want" in
        auto) [ -n "$rpn" ] && echo "$rpn" > "$card/gt_min_freq_mhz" 2>/dev/null ;;
        max)  [ -n "$rp0" ] && echo "$rp0" > "$card/gt_min_freq_mhz" 2>/dev/null && [ "$boot_only" = 0 ] && log "GPU clock floor ${rp0} MHz ($(basename "$card"))" ;;
        *[!0-9]*) warn "performance.gpu_min_freq: '$want' is not auto|max|<MHz>" ;;
        *)    echo "$want" > "$card/gt_min_freq_mhz" 2>/dev/null && [ "$boot_only" = 0 ] && log "GPU clock floor ${want} MHz ($(basename "$card"))" ;;
    esac
done
[ "$boot_only" = 1 ] && exit 0

# --- low latency: shallow C-states via the kernel command line ---
grub_drop=/etc/default/grub.d/91-kiosk-performance.cfg
if [ "$(cfg '.performance.low_latency' false)" = true ]; then
    content='GRUB_CMDLINE_LINUX_DEFAULT="$GRUB_CMDLINE_LINUX_DEFAULT intel_idle.max_cstate=1 processor.max_cstate=1"'
    [ -f "$grub_drop" ] && [ "$(cat "$grub_drop")" = "$content" ] || {
        run_on_real_root bash -c "mkdir -p /etc/default/grub.d && printf '%s\n' '$content' > $grub_drop && update-grub >/dev/null 2>&1" \
            && log "low_latency on: shallow C-states after the next reboot" || warn "could not write the GRUB drop-in"
    }
else
    [ -f "$grub_drop" ] && { run_on_real_root bash -c "rm -f $grub_drop && update-grub >/dev/null 2>&1" && log "low_latency off after the next reboot" || true; }
fi

# --- boot splash (display.splash): plymouth costs 1-3 s before X; false = plain black boot without it ---
splash_drop=/etc/default/grub.d/92-kiosk-splash.cfg
if [ "$(cfg '.display.splash' true)" = false ]; then
    content='GRUB_CMDLINE_LINUX_DEFAULT="quiet loglevel=3 vt.global_cursor_default=0"'
    [ -f "$splash_drop" ] && [ "$(cat "$splash_drop")" = "$content" ] || {
        run_on_real_root bash -c "mkdir -p /etc/default/grub.d && printf '%s\n' '$content' > $splash_drop && update-grub >/dev/null 2>&1" \
            && log "boot splash off after the next reboot" || warn "could not write the GRUB drop-in"
    }
else
    [ -f "$splash_drop" ] && { run_on_real_root bash -c "rm -f $splash_drop && update-grub >/dev/null 2>&1" && log "boot splash on after the next reboot" || true; }
fi

# --- i915 module options (Intel): frame buffer compression on, panel self refresh off ---
if has_gpu intel; then
    if write_file /etc/modprobe.d/kiosk-i915.conf <<'M'
options i915 enable_fbc=1 enable_psr=0
M
    then
        if overlayroot_active; then warn "i915 options written; rebuild the initramfs in rw mode (kioskctl mount rw)"
        elif command -v dracut >/dev/null; then dracut -f >/dev/null 2>&1 && log "i915 options set, initramfs rebuilt (reboot)" || warn "dracut failed"
        elif command -v update-initramfs >/dev/null; then update-initramfs -u >/dev/null 2>&1 && log "i915 options set, initramfs rebuilt (reboot)" || warn "update-initramfs failed"
        fi
    fi
fi

# --- TearFree in the Xorg config ---
tf="$(cfg '.display.tearfree' true)"; changed=0
for f in /etc/X11/xorg.conf.d/20-kiosk-modesetting.conf /etc/X11/xorg.conf.d/20-kiosk-amdgpu.conf; do
    [ -f "$f" ] || continue
    if grep -q "\"TearFree\" *\"$tf\"" "$f"; then continue; fi
    sed -i -E "s/(\"TearFree\" *\")(true|false)(\")/\1${tf}\3/" "$f" && changed=1
done
[ "$changed" = 1 ] && log "display.tearfree=$tf written; takes effect after: sudo systemctl restart kiosk-session"
exit 0
