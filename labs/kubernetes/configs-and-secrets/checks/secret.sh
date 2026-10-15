. "$LAB_LIB"
f=app/secret.yaml
[ -f "$f" ] || fail "app/secret.yaml does not exist."
[ "$(yaml_get "$f" 'd.kind')" = "Secret" ] || fail "The kind should be Secret."
[ "$(yaml_get "$f" 'd.metadata && d.metadata.name')" = "db-credentials" ] || fail "Name the Secret db-credentials."
[ "$(yaml_get "$f" 'd.type')" = "Opaque" ] || fail "Set type: Opaque."
raw=$(yaml_get "$f" 'd.data && d.data.DB_PASSWORD')
[ -n "$raw" ] && [ "$raw" != "undefined" ] || fail "Add DB_PASSWORD under data (a Secret's data values are base64)."
# JSON.stringify keeps a trailing newline visible (echo without -n), which the shell would otherwise strip
[ "$(yaml_get "$f" 'JSON.stringify(Buffer.from(String(d.data.DB_PASSWORD), "base64").toString("utf8"))')" = '"s3cr3t"' ] || fail "DB_PASSWORD does not decode to s3cr3t. Encode it with echo -n (no newline) and base64."
