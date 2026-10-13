. "$LAB_LIB"
f=app/pod.yaml
[ -f "$f" ] || fail "app/pod.yaml does not exist."
c=$(yaml_get "$f" 'JSON.stringify(d.spec && d.spec.containers && d.spec.containers[0])')
[ -n "$c" ] && [ "$c" != "null" ] || fail "Container definition is missing."

port=$(echo "$c" | jq -r '.ports[]?.containerPort // empty' | head -n 1)
[ "$port" = "80" ] || fail "Add containerPort: 80 under ports."

req_mem=$(echo "$c" | jq -r '.resources.requests.memory // ""')
req_cpu=$(echo "$c" | jq -r '.resources.requests.cpu // ""')
[ "$req_mem" = "64Mi" ] || fail "Set requests.memory to 64Mi."
[ "$req_cpu" = "50m" ] || fail "Set requests.cpu to 50m."

lim_mem=$(echo "$c" | jq -r '.resources.limits.memory // ""')
lim_cpu=$(echo "$c" | jq -r '.resources.limits.cpu // ""')
[ "$lim_mem" = "128Mi" ] || fail "Set limits.memory to 128Mi."
[ "$lim_cpu" = "100m" ] || fail "Set limits.cpu to 100m."
