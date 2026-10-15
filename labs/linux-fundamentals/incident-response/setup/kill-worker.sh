#!/bin/bash
# Starting state if you skipped ahead.
if [ ! -f .runaway.pid ] || [ ! -d "/proc/$(cat .runaway.pid 2>/dev/null)" ]; then
  mkdir -p bin
  cat << 'EOF' > bin/runaway-worker
#!/bin/bash
while true; do sleep 1; done
EOF
  chmod +x bin/runaway-worker
  ./bin/runaway-worker >/dev/null 2>&1 &
  echo $! > .runaway.pid
  disown
fi
