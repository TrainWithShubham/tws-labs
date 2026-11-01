. "$LAB_LIB"
f=checkout-app.yaml
[ -f "$f" ] || fail "checkout-app.yaml does not exist."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "checkout-app.yaml is not valid YAML."
[ "$(yaml_get "$f" 'd.kind')" = "Application" ] && [ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "checkout" ] || fail "Keep it an Application named checkout."
[ "$(yaml_get "$f" 'd.spec && d.spec.syncPolicy && typeof d.spec.syncPolicy.automated')" = "object" ] || fail "syncPolicy.automated is missing."
[ "$(yaml_get "$f" 'typeof d.spec.syncPolicy.automated.selfHeal + ":" + d.spec.syncPolicy.automated.selfHeal')" = "boolean:true" ] || fail "Manual changes still stick: selfHeal should be true."
[ "$(yaml_get "$f" 'typeof d.spec.syncPolicy.automated.prune + ":" + d.spec.syncPolicy.automated.prune')" = "boolean:true" ] || fail "Deleted resources are still orphaned: prune should be true."
yaml_get "$f" 'Array.isArray(d.spec.syncPolicy.syncOptions) && d.spec.syncPolicy.syncOptions.includes("CreateNamespace=true")' | grep -qx true ||
  fail "Keep the existing syncOptions (CreateNamespace=true)."
