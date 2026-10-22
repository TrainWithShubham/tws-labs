. "$LAB_LIB"

f="app/deployment.yaml"
[ -f "$f" ] || fail "app/deployment.yaml does not exist."

# Check if volumes array exists under spec.template.spec
has_volumes=$(yaml_get "$f" 'Boolean(d && d.spec && d.spec.template && d.spec.template.spec && Array.isArray(d.spec.template.spec.volumes) && d.spec.template.spec.volumes.length > 0)')
[ "$has_volumes" = "true" ] || fail "spec.template.spec must declare a volumes list."

# Check that the named volume references the expected PVC.
has_claim=$(yaml_get "$f" 'Boolean(d && d.spec && d.spec.template && d.spec.template.spec && Array.isArray(d.spec.template.spec.volumes) && d.spec.template.spec.volumes.some(v => v.name === "data-volume" && v.persistentVolumeClaim && v.persistentVolumeClaim.claimName === "app-storage"))')
[ "$has_claim" = "true" ] || fail "A volume named data-volume must reference the app-storage claim."
