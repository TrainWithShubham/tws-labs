. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
sel=$(yaml_get "$f" 'd.spec && d.spec.selector && d.spec.selector.matchLabels && d.spec.selector.matchLabels.app')
tpl=$(yaml_get "$f" 'd.spec && d.spec.template && d.spec.template.metadata && d.spec.template.metadata.labels && d.spec.template.metadata.labels.app')
[ -n "$sel" ] && [ "$sel" != "undefined" ] || fail "spec.selector.matchLabels.app is missing."
[ -n "$tpl" ] && [ "$tpl" != "undefined" ] || fail "The Pod template has no app label."
[ "$sel" = "$tpl" ] || fail "The selector ($sel) does not match the template's label ($tpl)."
