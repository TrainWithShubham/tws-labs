#!/bin/bash
mkdir -p bin
if [ ! -x bin/payment-worker ]; then
  cat << 'EOF' > bin/payment-worker
#!/bin/bash
while true; do sleep 1; done
EOF
  chmod +x bin/payment-worker
fi

need_spawn=1
if [ -f .worker.pid ]; then
  read -r wpid wtick wextra < .worker.pid 2>/dev/null || true
  if [ -n "$wpid" ] && [ -n "$wtick" ] && [ -z "$wextra" ] &&
     [ "$wpid" -eq "$wpid" ] 2>/dev/null && [ "$wpid" -gt 0 ] 2>/dev/null &&
     [ "$wtick" -eq "$wtick" ] 2>/dev/null && [ "$wtick" -gt 0 ] 2>/dev/null; then
    if [ -d "/proc/$wpid" ]; then
      wcomm=$(cat "/proc/$wpid/comm" 2>/dev/null || true)
      wstat=$(cat "/proc/$wpid/stat" 2>/dev/null || true)
      actual_tick=$(echo "${wstat##*) }" | awk '{print $20}')
      if [ "$wcomm" = "payment-worker" ] && [ "$actual_tick" = "$wtick" ]; then
        need_spawn=0
      fi
    fi
  fi
fi

if [ "$need_spawn" -eq 1 ]; then
  ./bin/payment-worker >/dev/null 2>&1 &
  wpid=$!
  raw=$(cat "/proc/$wpid/stat" 2>/dev/null || true)
  tick=$(echo "${raw##*) }" | awk '{print $20}')
  echo "$wpid $tick" > .worker.pid
  disown
fi

touch .service.lock
