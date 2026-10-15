#!/usr/bin/env bash
# Phase 2: create or update the Elastic Beanstalk application + Cluster Mode
# environment. Deploys "Climb" (product name) - AWS resource names intentionally
# stay `beanstalk-grows-*` to avoid recreating the already-verified live
# environment for a cosmetic rename.
set -euo pipefail

APP_NAME="${APP_NAME:-beanstalk-grows}"
ENV_NAME="${ENV_NAME:-beanstalk-grows-env}"
# See 02-build-and-push.sh: `aws configure get region` ignores env-var auth.
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-$(aws configure get region)}}"
ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
REPO_NAME="${REPO_NAME:-beanstalk-grows}"
IMAGE_URI="$ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$REPO_NAME:latest"

CLUSTER_ROLE_ARN="$(aws iam get-role --role-name aws-elasticbeanstalk-eks-cluster-role --query 'Role.Arn' --output text)"
NODE_ROLE_ARN="$(aws iam get-role --role-name aws-elasticbeanstalk-eks-node-role --query 'Role.Arn' --output text)"
OBS_ROLE_ARN="$(aws iam get-role --role-name aws-elasticbeanstalk-eks-observability-role --query 'Role.Arn' --output text)"

if ! aws elasticbeanstalk describe-applications --application-names "$APP_NAME" \
    --query 'Applications[0]' --output text 2>/dev/null | grep -qv '^None$'; then
  aws elasticbeanstalk create-application \
    --application-name "$APP_NAME" \
    --tags Key=project,Value=beanstalk-grows >/dev/null
  echo "Created application $APP_NAME"
fi

# Capacity knobs. Seats are per replica (MAX_CONCURRENT_SESSIONS=5 in the app), and
# CPU autoscaling does NOT react to idle shells, so a visitor spike won't add replicas
# by itself: raise MIN_REPLICA ahead of an announcement (seats = replicas x 5), and
# lower it again afterwards. MAX_REPLICA is the hard ceiling on spend.
MIN_REPLICA="${MIN_REPLICA:-1}"
MAX_REPLICA="${MAX_REPLICA:-8}"

VERSION_LABEL="v-$(date +%Y%m%d%H%M%S)"
aws elasticbeanstalk create-application-version \
  --application-name "$APP_NAME" \
  --version-label "$VERSION_LABEL" \
  --image-configuration "Source={Uri=$IMAGE_URI}" \
  --tags Key=project,Value=beanstalk-grows >/dev/null
echo "Created application version $VERSION_LABEL from $IMAGE_URI"

# ALB target-group stickiness isn't a first-class option in the eks:alb namespace,
# but raw-annotation passes arbitrary Kubernetes Ingress annotations straight to the
# AWS Load Balancer Controller, which is where target-group-attributes actually lives.
# The Value is itself a JSON document containing commas, which the AWS CLI's
# shorthand --option-settings syntax can't parse - so option-settings are written
# to a JSON file instead (same approach the docs use for scaler-metadata).
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

STICKY_ANNOTATION_VALUE='[{"alb.ingress.kubernetes.io/target-group-attributes":"stickiness.enabled=true,stickiness.type=lb_cookie,stickiness.lb_cookie.duration_seconds=1800"}]'

cat > "$TMP_DIR/update-options.json" <<JSON
[
  {"Namespace":"aws:elasticbeanstalk:eks:environment","OptionName":"service-port","Value":"8080"},
  {"Namespace":"aws:elasticbeanstalk:eks:environment","OptionName":"cpu","Value":"500m"},
  {"Namespace":"aws:elasticbeanstalk:eks:environment","OptionName":"memory","Value":"512Mi"},
  {"Namespace":"aws:elasticbeanstalk:eks:environment:autoscaling","OptionName":"min-replica","Value":"$MIN_REPLICA"},
  {"Namespace":"aws:elasticbeanstalk:eks:environment:autoscaling","OptionName":"max-replica","Value":"$MAX_REPLICA"},
  {"Namespace":"aws:elasticbeanstalk:eks:environment:autoscaling:trigger","OptionName":"cpu-metric-type","Value":"Utilization"},
  {"Namespace":"aws:elasticbeanstalk:eks:environment:autoscaling:trigger","OptionName":"cpu-value","Value":"50"},
  {"Namespace":"aws:elasticbeanstalk:eks:alb","OptionName":"raw-annotation","Value":$(printf '%s' "$STICKY_ANNOTATION_VALUE" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read()))')}
]
JSON

# Invite tokens for the gated Cluster Mode lab (comma-separated; GitHub secret LAB_ACCESS_TOKENS).
# Cluster Mode takes application env vars as ONE option, env-variables, holding a JSON object.
# The value goes through the environment, never the command line or the log.
if [ -n "${LAB_ACCESS_TOKENS:-}" ]; then
  OPTS_FILE="$TMP_DIR/update-options.json" python3 -c '
import json, os
path = os.environ["OPTS_FILE"]
with open(path) as f:
    opts = json.load(f)
env = {"LAB_ACCESS_TOKENS": os.environ["LAB_ACCESS_TOKENS"], "USAGE_STATS": "1"}
# Optional: an admin token turns on /admin/stats; a fixed salt keeps distinct-visitor counts consistent across replicas.
for name in ("ADMIN_TOKEN", "USAGE_SALT"):
    if os.environ.get(name):
        env[name] = os.environ[name]
opts.append({"Namespace": "aws:elasticbeanstalk:eks:environment", "OptionName": "env-variables",
             "Value": json.dumps(env)})
with open(path, "w") as f:
    json.dump(opts, f)
'
  echo "Invite tokens configured for the gated lab; usage counters on${ADMIN_TOKEN:+, admin page on}."
else
  echo "WARNING: LAB_ACCESS_TOKENS is not set - every hosted lab will refuse everyone (set the GitHub secret)." >&2
fi

if aws elasticbeanstalk describe-environments --environment-names "$ENV_NAME" \
    --query 'Environments[0].Status' --output text 2>/dev/null | grep -qv '^None$\|Terminated'; then
  echo "Environment $ENV_NAME already exists - updating in place with new version + options."
  aws elasticbeanstalk update-environment \
    --environment-name "$ENV_NAME" \
    --version-label "$VERSION_LABEL" \
    --option-settings "file://$TMP_DIR/update-options.json"
  exit 0
fi

python3 -c "
import json
with open('$TMP_DIR/update-options.json') as f:
    opts = json.load(f)
opts += [
    {'Namespace': 'aws:elasticbeanstalk:eks', 'OptionName': 'cluster-role', 'Value': '$CLUSTER_ROLE_ARN'},
    {'Namespace': 'aws:elasticbeanstalk:eks', 'OptionName': 'node-role', 'Value': '$NODE_ROLE_ARN'},
    {'Namespace': 'aws:elasticbeanstalk:eks:environment', 'OptionName': 'observability-role', 'Value': '$OBS_ROLE_ARN'},
]
with open('$TMP_DIR/create-options.json', 'w') as f:
    json.dump(opts, f)
"

echo "Creating Cluster Mode environment $ENV_NAME (this takes 15-20 minutes on a first run)..."
aws elasticbeanstalk create-environment \
  --application-name "$APP_NAME" \
  --environment-name "$ENV_NAME" \
  --version-label "$VERSION_LABEL" \
  --tier Name=Cluster,Type=EKS \
  --tags Key=project,Value=beanstalk-grows \
  --option-settings "file://$TMP_DIR/create-options.json"

echo
echo "Poll status with:"
echo "  aws elasticbeanstalk wait environment-exists --environment-names $ENV_NAME"
echo "  (expect 'Max attempts exceeded' at least once on a first run per AWS's own tutorial - just re-run it)"
echo
echo "Then check health/URL with:"
echo "  aws elasticbeanstalk describe-environments --environment-names $ENV_NAME \\"
echo "    --query 'Environments[0].[Status,Health,HealthStatus,CNAME]' --output table"
