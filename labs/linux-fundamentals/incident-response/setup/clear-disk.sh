#!/bin/bash
# Starting state if you skipped ahead: ensure runaway-worker is stopped and log file exists.
pkill -f runaway-worker 2>/dev/null || true
mkdir -p var/log
if [ ! -f var/log/app-error.log ] || [ "$(stat -c %s var/log/app-error.log 2>/dev/null || echo 0)" -lt 1024 ]; then
  truncate -s 50M var/log/app-error.log
fi
