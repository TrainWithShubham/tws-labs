. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
img=$(yaml_get "$f" 'd.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers && d.spec.template.spec.containers[0] && d.spec.template.spec.containers[0].image')
[ "$img" = "nginx:1.27" ] || fail "Pin the image to nginx:1.27 (it is $img now)."
