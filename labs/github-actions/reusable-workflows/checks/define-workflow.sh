. "$LAB_LIB"
f=shop/.github/workflows/deploy.yml
[ -f "$f" ] || fail "Reusable workflow file shop/.github/workflows/deploy.yml does not exist."

call=$(yaml_get "$f" 'Boolean((d[true] || d.on)?.workflow_call)')
[ "$call" = "true" ] || fail "deploy.yml must trigger on workflow_call."

perm=$(yaml_get "$f" 'Boolean(d.permissions?.contents === "read" || d.permissions === "read-all")')
[ "$perm" = "true" ] || fail "Add permissions: contents: read for least privilege in deploy.yml."

req=$(yaml_get "$f" 'Boolean((d[true] || d.on)?.workflow_call?.inputs?.environment?.required === true)')
[ "$req" = "true" ] || fail "The environment input must be marked required: true."

type=$(yaml_get "$f" '(d[true] || d.on)?.workflow_call?.inputs?.environment?.type')
[ "$type" = "string" ] || fail "The environment input must be of type string."

steps=$(yaml_get "$f" 'Boolean(d.jobs?.deploy?.steps?.length)')
[ "$steps" = "true" ] || fail "The deploy job steps are missing in deploy.yml."

has_checkout=$(yaml_get "$f" 'Boolean((d.jobs?.deploy?.steps || []).some(s => /^actions\/checkout(@(v[0-9]+(\.[0-9]+)*|[a-f0-9]{40}))?$/.test(s.uses || "")))')
[ "$has_checkout" = "true" ] || fail "Check out code with actions/checkout (e.g. actions/checkout@v4 or commit SHA) in the deploy job."

has_run=$(yaml_get "$f" 'Boolean((d.jobs?.deploy?.steps || []).some(s => /(^|\s)\.\/scripts\/deploy\.sh(\s|$)/.test(s.run || "") && String(s.run || "").includes("inputs.environment")))')
[ "$has_run" = "true" ] || fail "Add a step running ./scripts/deploy.sh passing inputs.environment."
