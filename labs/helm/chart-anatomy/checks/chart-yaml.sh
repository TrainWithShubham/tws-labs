. "$LAB_LIB"
f=shop/Chart.yaml
[ -f "$f" ] || fail "shop/Chart.yaml does not exist yet."
[ -n "$(yaml_get "$f" 'd && typeof d === "object" ? 1 : ""')" ] || fail "Chart.yaml is not valid YAML (or is empty)."
[ "$(yaml_get "$f" 'd.apiVersion')" = "v2" ] || fail "apiVersion should be v2 (the Helm 3 chart format)."
[ "$(yaml_get "$f" 'd.name')" = "shop" ] || fail "name should be shop."
yaml_get "$f" 'typeof d.version === "string" && /^[0-9]+\.[0-9]+\.[0-9]+([-+][0-9A-Za-z.+-]+)?$/.test(d.version)' | grep -qx true ||
  fail "version should be a SemVer string like 0.1.0 (major.minor.patch)."
[ "$(yaml_get "$f" 'typeof d.appVersion')" = "string" ] || fail "appVersion is missing or not a string: quote it, e.g. \"1.27.0\"."
yaml_get "$f" 'd.appVersion.trim().length > 0' | grep -qx true || fail "appVersion is empty."
