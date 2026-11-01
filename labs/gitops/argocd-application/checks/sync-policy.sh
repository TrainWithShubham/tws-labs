. "$LAB_LIB"
f=guestbook-app.yaml
[ -f "$f" ] || fail "guestbook-app.yaml does not exist."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "guestbook-app.yaml is not valid YAML."
[ "$(yaml_get "$f" 'd.spec && typeof d.spec.syncPolicy')" = "object" ] || fail "spec.syncPolicy is missing."
[ "$(yaml_get "$f" 'typeof d.spec.syncPolicy.automated')" = "object" ] || fail "syncPolicy.automated is missing: it is a map under syncPolicy."
[ "$(yaml_get "$f" 'd.spec.syncPolicy.automated.prune')" = "true" ] && [ "$(yaml_get "$f" 'typeof d.spec.syncPolicy.automated.prune')" = "boolean" ] || fail "automated.prune should be true (a boolean, not quoted)."
[ "$(yaml_get "$f" 'typeof d.spec.syncPolicy.automated.selfHeal')" = "boolean" ] && [ "$(yaml_get "$f" 'd.spec.syncPolicy.automated.selfHeal')" = "true" ] || fail "automated.selfHeal should be true (a boolean, not quoted)."
yaml_get "$f" 'Array.isArray(d.spec.syncPolicy.syncOptions) && d.spec.syncPolicy.syncOptions.includes("CreateNamespace=true")' | grep -qx true ||
  fail "syncPolicy.syncOptions should be a list containing CreateNamespace=true."
