. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
pod='d.spec && d.spec.template && d.spec.template.spec'
vol=$(yaml_get "$f" "($pod) && (($pod).volumes || []).filter(v => v.configMap && v.configMap.name === 'app-config').map(v => v.name)[0]")
[ -n "$vol" ] && [ "$vol" != "undefined" ] || fail "Add a volume to the Pod that is backed by the ConfigMap app-config."
mounted=$(yaml_get "$f" "Boolean(($pod) && ($pod).containers && ($pod).containers[0] && (($pod).containers[0].volumeMounts || []).some(m => m.name === '$vol' && m.mountPath === '/etc/app'))")
[ "$mounted" = "true" ] || fail "Mount that volume in the container at /etc/app (the mount's name must match the volume's name)."
