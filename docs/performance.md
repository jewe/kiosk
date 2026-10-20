# Chrome performance

How to measure, what the kiosk does by default, and which optional levers exist. Rule: change one thing, measure twice, keep it only if the gain is larger than the run-to-run noise (about 5 %).

## Measure

| Command | What it does |
|---|---|
| `sudo kioskctl bench info` | GPU, Xorg driver, VA-API profiles, clocks, and Chrome's own `chrome://gpu` feature list. Look here first: "Rasterization", "Canvas" and "Video Decode" must say *Hardware accelerated* |
| `sudo kioskctl bench gpu` | glmark2 fullscreen, about 8 minutes. Score to the journal (`kiosk-bench`) |
| `sudo kioskctl bench motionmark` | MotionMark with the production Chrome flags, about 6 minutes. The score is read through the DevTools protocol and written to `/opt/kiosk/data/bench/motionmark-*.json` and the journal. Uses an offline copy of MotionMark (cloned once into `/opt/kiosk/data/bench/MotionMark`); `--online` uses browserbench.org |
| `sudo kioskctl bench ab "" "--enable-features=Vulkan"` | MotionMark alternating with two extra flag sets, 2 rounds each (third argument = rounds), prints both medians |
| `kioskctl history` | glmark2 and MotionMark results next to the metrics |

The kiosk apps are stopped during a benchmark and started again afterwards. Every result JSON contains governor, EPP, GPU clock and CPU temperature before and after the run, so a thermal throttle shows up as a dropping clock.

## What the kiosk does by default

Chrome flags (`apps/web/chrome-flags.sh`, used by the apps and by the benchmark):

- rendering on the GPU: `--enable-gpu-rasterization --enable-zero-copy --enable-native-gpu-memory-buffers`, features `CanvasOopRasterization`, `VaapiVideoDecodeLinuxGL`, `VaapiIgnoreDriverChecks`, `--ignore-gpu-blocklist`
- no throttling of covered windows: `--disable-renderer-backgrounding --disable-background-timer-throttling --disable-backgrounding-occluded-windows` (several apps per screen overlap; without these a partly covered window runs its timers at 1 Hz)
- no background work: `--disable-background-networking --disable-component-update --disable-sync --disable-breakpad --metrics-recording-only`, features `MediaRouter`, `OptimizationHints`, `Translate` off
- `--ozone-platform=x11 --force-device-scale-factor=1`
- `--enable-features=` / `--disable-features=` from `chrome.flags` and `apps[].extra_flags` are merged into one flag each (Chrome only honours the last one)

Shader cache: the Chrome profile is tmpfs, so compiled GPU shaders are copied to `/opt/kiosk/state/chrome/<app>` when an app stops and restored before it starts. This removes the jank in the first seconds after a reboot; it does not change benchmark scores.

System: performance governor and `energy_performance_preference=performance` before the session starts (`kiosk-cpufreq.service`), no compositor, Xorg modesetting with glamor and TearFree, Intel `i915 enable_fbc=1 enable_psr=0`, Chrome profile on tmpfs.

## Optional levers (config, `sudo kioskctl apply`)

| Key | Effect | Cost |
|---|---|---|
| `chrome.flags: ["--enable-features=Vulkan"]` | Vulkan instead of GL for compositing and raster. Faster on some Intel/AMD drivers, unstable on others. Try with `bench ab` first | crashes or black windows on bad drivers |
| `display.tearfree: false` | removes the extra per-frame copy of the DDX. A few percent more throughput | possible tearing on scrolls; Chrome is vsynced itself, so in a fullscreen kiosk it is usually invisible. Needs `sudo systemctl restart kiosk-session` |
| `performance.gpu_min_freq: max` | Intel GPU never clocks down: no ramp-up jitter on bursty animation | heat and power; the clock is visible in `kioskctl metrics` as `gpu_mhz` |
| `performance.low_latency: true` | kernel options `intel_idle.max_cstate=1 processor.max_cstate=1`, less wake-up latency for touch and animation. Reboot | heat and power. Only if frame times are jittery |
| `chrome.gpu: software` | `--disable-gpu`. Only for broken drivers | everything on the CPU |

## Reference scores

| Device | glmark2 | MotionMark | Notes |
|---|---|---|---|
| kiosk-01, Intel UHD 730, Ubuntu 26.04 | 1174 | *to be measured* | default flags; measure before and after the flag change (commit "Chrome performance") |

## When a page is slow

1. `sudo kioskctl bench info`: if anything in `chrome://gpu` says *Software only*, the driver is the problem (check `vainfo`, `glxinfo`, the Xorg log), not the page.
2. `kioskctl metrics`: `cpu_temp`, `throttle` and `gpu_mhz` tell whether the box throttles. `tests/stress.sh` shows memory growth.
3. Compare with the reference score above; a much lower MotionMark score on the same hardware means a system problem, the same score means the page itself.
