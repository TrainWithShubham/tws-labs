. "$LAB_LIB"
f=app/deployment.yaml
[ -f "$f" ] || fail "app/deployment.yaml does not exist."
kind=$(yaml_get "$f" 'd.kind')
[ "$kind" = "Deployment" ] || fail "The kind should be Deployment."
api=$(yaml_get "$f" 'd.apiVersion')
[ "$api" = "apps/v1" ] || fail "The apiVersion should be apps/v1."

name=$(yaml_get "$f" 'd.metadata && d.metadata.name')
[ "$name" = "web-deployment" ] || fail "Name the Deployment web-deployment in metadata.name."

replicas=$(yaml_get "$f" 'd.spec && d.spec.replicas')
[ "$replicas" = "3" ] || fail "Set spec.replicas to 3."

sel_label=$(yaml_get "$f" 'd.spec && d.spec.selector && d.spec.selector.matchLabels && d.spec.selector.matchLabels.app')
[ "$sel_label" = "web" ] || fail "Set spec.selector.matchLabels.app to web."

tpl_label=$(yaml_get "$f" 'd.spec && d.spec.template && d.spec.template.metadata && d.spec.template.metadata.labels && d.spec.template.metadata.labels.app')
[ "$tpl_label" = "web" ] || fail "Set spec.template.metadata.labels.app to web to match the selector."

containers=$(yaml_get "$f" 'JSON.stringify(d.spec && d.spec.template && d.spec.template.spec && d.spec.template.spec.containers)')
[ -n "$containers" ] && [ "$containers" != "null" ] || fail "spec.template.spec.containers list is missing."

c=$(echo "$containers" | jq -c '.[]? | select((.image // "") | test("^nginx(:1\\.27)?$"))')
[ -n "$c" ] || fail "The template should run container nginx with image nginx:1.27."
