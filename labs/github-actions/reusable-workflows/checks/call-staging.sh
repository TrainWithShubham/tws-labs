. "$LAB_LIB"
f=shop/.github/workflows/main.yml
[ -f "$f" ] || fail "Workflow file shop/.github/workflows/main.yml is missing."

has_job=$(yaml_get "$f" 'Boolean(d.jobs && d.jobs["deploy-staging"])')
[ "$has_job" = "true" ] || fail "Add a job named deploy-staging in main.yml."

uses=$(yaml_get "$f" 'String(d.jobs?.["deploy-staging"]?.uses || "")')
case "$uses" in
  ./.github/workflows/deploy.yml) ;;
  *) fail "The deploy-staging job must use ./.github/workflows/deploy.yml.";;
esac

env_val=$(yaml_get "$f" 'String(d.jobs?.["deploy-staging"]?.with?.environment || "")')
[ "$env_val" = "staging" ] || fail "Pass environment: staging under with in the deploy-staging job."

has_sec=$(yaml_get "$f" 'Boolean(d.jobs?.["deploy-staging"]?.secrets === "inherit" || (typeof d.jobs?.["deploy-staging"]?.secrets === "object" && d.jobs?.["deploy-staging"]?.secrets !== null))')
[ "$has_sec" = "true" ] || fail "Pass secrets to the deploy-staging job (using secrets: inherit or explicit mapping)."

has_steps=$(yaml_get "$f" 'Boolean(d.jobs?.["deploy-staging"]?.steps)')
[ "$has_steps" = "false" ] || fail "A job that calls a reusable workflow cannot define steps."

has_runs_on=$(yaml_get "$f" 'Boolean(d.jobs?.["deploy-staging"]?.["runs-on"])')
[ "$has_runs_on" = "false" ] || fail "A job that calls a reusable workflow cannot define runs-on (the called workflow manages its own runner)."

