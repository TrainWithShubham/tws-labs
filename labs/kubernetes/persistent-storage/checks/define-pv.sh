. "$LAB_LIB"

f="app/pv.yaml"
[ -f "$f" ] || fail "app/pv.yaml does not exist yet."

# Verify kind
kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "PersistentVolume" ] || fail "app/pv.yaml kind must be PersistentVolume."

# Verify apiVersion
api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "v1" ] || fail "PersistentVolume apiVersion must be v1."

# Verify name
name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "local-pv" ] || fail "metadata.name must be local-pv."

# Require the same classless storage requested by the PVC.
has_empty_storage_class=$(yaml_get "$f" 'Boolean(d && d.spec && typeof d.spec.storageClassName === "string" && d.spec.storageClassName === "")')
[ "$has_empty_storage_class" = "true" ] || fail 'spec.storageClassName must be an empty string ("").'

# Verify capacity
capacity=$(yaml_get "$f" 'd && d.spec && d.spec.capacity && d.spec.capacity.storage')
[ "$capacity" = "1Gi" ] || [ "$capacity" = "1024Mi" ] || fail "spec.capacity.storage must be 1Gi."

# Verify accessModes
has_mode=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.accessModes) && d.spec.accessModes.includes("ReadWriteOnce"))')
[ "$has_mode" = "true" ] || fail "spec.accessModes must include ReadWriteOnce."

# Verify persistentVolumeReclaimPolicy
reclaim=$(yaml_get "$f" 'd && d.spec && d.spec.persistentVolumeReclaimPolicy')
[ "$reclaim" = "Retain" ] || fail "spec.persistentVolumeReclaimPolicy must be Retain."

# Verify hostPath
has_path=$(yaml_get "$f" 'Boolean(d && d.spec && d.spec.hostPath && d.spec.hostPath.path === "/mnt/data")')
[ "$has_path" = "true" ] || fail "spec.hostPath.path must be set to /mnt/data."
