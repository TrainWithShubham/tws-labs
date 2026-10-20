. "$LAB_LIB"
f=shop/.github/workflows/deploy.yml
[ -f "$f" ] || fail "Reusable workflow file shop/.github/workflows/deploy.yml is missing."

has_sec=$(yaml_get "$f" 'Boolean((d[true] || d.on)?.workflow_call?.secrets && "DEPLOY_TOKEN" in (d[true] || d.on).workflow_call.secrets)')
[ "$has_sec" = "true" ] || fail "Declare the DEPLOY_TOKEN secret under on.workflow_call.secrets."

is_req=$(yaml_get "$f" 'Boolean((d[true] || d.on)?.workflow_call?.secrets?.["DEPLOY_TOKEN"]?.required === true)')
[ "$is_req" = "false" ] || fail "DEPLOY_TOKEN should be an optional secret (required: false)."

token_env=$(yaml_get "$f" 'String((d.jobs?.deploy?.steps || []).find(s => /(^|\s)\.\/scripts\/deploy\.sh(\s|$)/.test(s.run || ""))?.env?.DEPLOY_TOKEN || "")')
printf '%s' "$token_env" | grep -Eq '^\$\{\{[[:space:]]*secrets\.DEPLOY_TOKEN[[:space:]]*\}\}$' ||
  fail 'Set env.DEPLOY_TOKEN to ${{ secrets.DEPLOY_TOKEN }} in the deploy step.'
