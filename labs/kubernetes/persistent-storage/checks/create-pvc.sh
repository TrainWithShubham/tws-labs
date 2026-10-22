. "$LAB_LIB"

f="app/pvc.yaml"
[ -f "$f" ] || fail "app/pvc.yaml does not exist yet."

# Verify kind
kind=$(yaml_get "$f" 'd && d.kind')
[ "$kind" = "PersistentVolumeClaim" ] || fail "app/pvc.yaml kind must be PersistentVolumeClaim."

# Verify apiVersion
api=$(yaml_get "$f" 'd && d.apiVersion')
[ "$api" = "v1" ] || fail "PersistentVolumeClaim apiVersion must be v1."

# Verify name
name=$(yaml_get "$f" 'd && d.metadata && d.metadata.name')
[ "$name" = "app-storage" ] || fail "metadata.name must be app-storage."

# Require a classless claim so it binds to the lab's static PV, even on clusters with a default StorageClass.
has_empty_storage_class=$(yaml_get "$f" 'Boolean(d && d.spec && typeof d.spec.storageClassName === "string" && d.spec.storageClassName === "")')
[ "$has_empty_storage_class" = "true" ] || fail 'spec.storageClassName must be an empty string ("").'

# Verify accessModes includes ReadWriteOnce
has_mode=$(yaml_get "$f" 'Boolean(d && d.spec && Array.isArray(d.spec.accessModes) && d.spec.accessModes.includes("ReadWriteOnce"))')
[ "$has_mode" = "true" ] || fail "spec.accessModes must include ReadWriteOnce."

# Verify resources.requests.storage
storage=$(yaml_get "$f" 'd && d.spec && d.spec.resources && d.spec.resources.requests && d.spec.resources.requests.storage')
[ "$storage" = "1Gi" ] || [ "$storage" = "1024Mi" ] || fail "spec.resources.requests.storage must be 1Gi."
