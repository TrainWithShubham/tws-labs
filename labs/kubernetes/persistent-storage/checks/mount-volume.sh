. "$LAB_LIB"

f="app/deployment.yaml"
[ -f "$f" ] || fail "app/deployment.yaml does not exist."

# Check if the app container has volumeMounts
has_mounts=$(yaml_get "$f" '(() => {
  if (!d || !d.spec || !d.spec.template || !d.spec.template.spec || !Array.isArray(d.spec.template.spec.containers)) return false;
  const app = d.spec.template.spec.containers.find(c => c.name === "app");
  return Boolean(app && Array.isArray(app.volumeMounts) && app.volumeMounts.length > 0);
})()')
[ "$has_mounts" = "true" ] || fail "The app container must declare volumeMounts."

# Check if mountPath is /data
has_path=$(yaml_get "$f" '(() => {
  if (!d || !d.spec || !d.spec.template || !d.spec.template.spec || !Array.isArray(d.spec.template.spec.containers)) return false;
  const app = d.spec.template.spec.containers.find(c => c.name === "app");
  return Boolean(app && Array.isArray(app.volumeMounts) && app.volumeMounts.some(m => m.mountPath === "/data"));
})()')
[ "$has_path" = "true" ] || fail "The app container volumeMounts must specify mountPath: /data."

# Check that the volumeMount names data-volume at /data
has_mount_name=$(yaml_get "$f" '(() => {
  if (!d || !d.spec || !d.spec.template || !d.spec.template.spec || !Array.isArray(d.spec.template.spec.containers)) return false;
  const app = d.spec.template.spec.containers.find(c => c.name === "app");
  return Boolean(app && Array.isArray(app.volumeMounts) && app.volumeMounts.some(m => m.name === "data-volume" && m.mountPath === "/data"));
})()')
[ "$has_mount_name" = "true" ] || fail "The app container must mount data-volume at /data."
