. "$LAB_LIB"
f=app/pod.yaml
[ -f "$f" ] || fail "app/pod.yaml does not exist."
probe=$(yaml_get "$f" 'JSON.stringify(d.spec && d.spec.containers && d.spec.containers[0] && d.spec.containers[0].livenessProbe)')
[ -n "$probe" ] && [ "$probe" != "null" ] || fail "Add livenessProbe to the container."

path=$(echo "$probe" | jq -r '.httpGet.path // ""')
port=$(echo "$probe" | jq -r '.httpGet.port // ""')
[ "$path" = "/" ] || fail "The livenessProbe should check httpGet path /."
[ "$port" = "80" ] || fail "The livenessProbe should check httpGet port 80."

delay=$(echo "$probe" | jq -r '.initialDelaySeconds // 0')
[ "$delay" -ge 3 ] && [ "$delay" -le 10 ] || fail "Set initialDelaySeconds: 5."
