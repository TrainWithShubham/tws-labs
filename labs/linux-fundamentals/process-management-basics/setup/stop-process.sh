#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
if [ ! -s sleep.pid ]; then
  nohup sleep 300 > /dev/null 2>&1 &
  echo $! > sleep.pid
fi
