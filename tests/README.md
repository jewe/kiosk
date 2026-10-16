# tests — stress test, benchmarks

- `stress.sh [minutes] [events/s]` (`kioskctl test stress`): random clicks, drags, scrolls and keys via xdotool, memory sampled every 30 s to `/opt/kiosk/data/stress/*.csv`. PASS = no app restarts and memory growth under 10 %.
- `bench.sh info|gpu|motionmark` (`kioskctl bench`): GPU/driver/VA-API report, glmark2 score (journal tag `kiosk-bench`), MotionMark opened in Chrome for 5 minutes (read the score on screen).
- `kioskctl doctor` is the install self-test.
