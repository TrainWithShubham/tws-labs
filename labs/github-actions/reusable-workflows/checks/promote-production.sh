. "$LAB_LIB"
f=shop/.github/workflows/main.yml
[ -f "$f" ] || fail "Workflow file shop/.github/workflows/main.yml is missing."

has_job=$(yaml_get "$f" 'Boolean(d.jobs && d.jobs["deploy-production"])')
[ "$has_job" = "true" ] || fail "Add a job named deploy-production in main.yml."

needs=$(yaml_get "$f" 'String(d.jobs?.["deploy-production"]?.needs || "")')
case "$needs" in
  *deploy-staging*) ;;
  *) fail "The deploy-production job must have needs: [deploy-staging].";;
esac

uses=$(yaml_get "$f" 'String(d.jobs?.["deploy-production"]?.uses || "")')
case "$uses" in
  ./.github/workflows/deploy.yml) ;;
  *) fail "The deploy-production job must use ./.github/workflows/deploy.yml.";;
esac

env_val=$(yaml_get "$f" 'String(d.jobs?.["deploy-production"]?.with?.environment || "")')
[ "$env_val" = "production" ] || fail "Pass environment: production under with in the deploy-production job."

has_sec=$(yaml_get "$f" 'Boolean(d.jobs?.["deploy-production"]?.secrets === "inherit" || (typeof d.jobs?.["deploy-production"]?.secrets === "object" && d.jobs?.["deploy-production"]?.secrets !== null))')
[ "$has_sec" = "true" ] || fail "Pass secrets to the deploy-production job (using secrets: inherit or explicit mapping)."

has_steps=$(yaml_get "$f" 'Boolean(d.jobs?.["deploy-production"]?.steps)')
[ "$has_steps" = "false" ] || fail "A job that calls a reusable workflow cannot define steps."

has_runs_on=$(yaml_get "$f" 'Boolean(d.jobs?.["deploy-production"]?.["runs-on"])')
[ "$has_runs_on" = "false" ] || fail "A job that calls a reusable workflow cannot define runs-on."

