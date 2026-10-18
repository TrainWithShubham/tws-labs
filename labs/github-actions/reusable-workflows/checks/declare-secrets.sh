. "$LAB_LIB"
f=shop/.github/workflows/deploy.yml
[ -f "$f" ] || fail "Reusable workflow file shop/.github/workflows/deploy.yml is missing."

has_sec=$(yaml_get "$f" 'Boolean((d[true] || d.on)?.workflow_call?.secrets && "deploy-token" in (d[true] || d.on).workflow_call.secrets)')
[ "$has_sec" = "true" ] || fail "Declare the deploy-token secret under on.workflow_call.secrets."

is_req=$(yaml_get "$f" 'Boolean((d[true] || d.on)?.workflow_call?.secrets?.["deploy-token"]?.required === true)')
[ "$is_req" = "false" ] || fail "deploy-token should be an optional secret (required: false)."

token_env=$(yaml_get "$f" 'String((d.jobs?.deploy?.steps || []).find(s => /(^|\s)\.\/scripts\/deploy\.sh(\s|$)/.test(s.run || ""))?.env?.DEPLOY_TOKEN || "")')
case "$token_env" in
  *secrets.deploy-token*) ;;
  *) fail "Set env.DEPLOY_TOKEN to secrets.deploy-token in the deploy step.";;
esac
