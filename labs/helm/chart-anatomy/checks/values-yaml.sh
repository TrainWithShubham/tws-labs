. "$LAB_LIB"
f=shop/values.yaml
[ -f "$f" ] || fail "shop/values.yaml does not exist yet."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "values.yaml is not valid YAML (or is empty)."
yaml_get "$f" 'Number.isInteger(d.replicaCount) && d.replicaCount >= 1' | grep -qx true || fail "replicaCount should be a whole number, 1 or more."
yaml_get "$f" 'd.image && typeof d.image === "object" && typeof d.image.repository === "string" && d.image.repository.length > 0' | grep -qx true ||
  fail "image.repository is missing (image should be a map with repository and tag inside)."
yaml_get "$f" 'd.image && d.image.tag !== undefined && d.image.tag !== null && String(d.image.tag).length > 0' | grep -qx true || fail "image.tag is missing."
yaml_get "$f" 'd.service && typeof d.service === "object" && Number.isInteger(d.service.port)' | grep -qx true || fail "service.port should be a number under a service: map."
