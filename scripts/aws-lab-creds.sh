#!/usr/bin/env bash
# Short-lived AWS credentials for the AWS labs, so no long-lived keys ever reach the lab container.
#   eval "$(scripts/aws-lab-creds.sh arn:aws:iam::<your-account-id>:role/tws-labs-learner)"
#   AWS=1 ./start_local_labs.sh
# Run it on YOUR machine (it needs the AWS CLI and your normal credentials). It prints three `export` lines on stdout and
# nothing else there; messages go to stderr. The credentials expire after one hour by default (--duration SECONDS, 900-14400: the role's own maximum is 4 hours).
set -euo pipefail

say() { printf '%s\n' "$*" >&2; }
die() { say "$*"; exit 1; }

ROLE="${1:-}"
[ -n "$ROLE" ] || die "usage: eval \"\$(scripts/aws-lab-creds.sh <role-arn> [--duration SECONDS])\"   (the role comes from deploy/learner-role.yaml)"
shift
DURATION=3600
if [ "${1:-}" = "--duration" ]; then
  DURATION="${2:-}"
  [[ "$DURATION" =~ ^[0-9]+$ ]] && [ "$DURATION" -ge 900 ] && [ "$DURATION" -le 14400 ] || die "--duration must be a whole number of seconds from 900 to 14400 (the learner role allows sessions of up to 4 hours)"
fi

[[ "$ROLE" =~ ^arn:aws:iam::[0-9]{12}:role/[A-Za-z0-9+=,.@_/-]+$ ]] || die "That does not look like an IAM role ARN (arn:aws:iam::<12-digit account id>:role/<name>)."
command -v aws >/dev/null 2>&1 || die "The AWS CLI is not installed on this machine. Install it first: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"

OUT="$(aws sts assume-role --role-arn "$ROLE" --role-session-name tws-labs --duration-seconds "$DURATION" \
  --query 'Credentials.[AccessKeyId,SecretAccessKey,SessionToken]' --output text)" || die "assume-role failed. Check that your own credentials work (aws sts get-caller-identity) and that the role trusts you."

IFS=$'\t' read -r KEY SECRET TOKEN <<<"$OUT"
# What AWS returns is base64-ish text; refuse anything else so the output is always safe to eval.
for v in "$KEY" "$SECRET" "$TOKEN"; do
  [[ "$v" =~ ^[A-Za-z0-9/+=_-]+$ ]] || die "AWS returned credentials in an unexpected format; not printing them."
done

printf "export AWS_ACCESS_KEY_ID='%s'\n" "$KEY"
printf "export AWS_SECRET_ACCESS_KEY='%s'\n" "$SECRET"
printf "export AWS_SESSION_TOKEN='%s'\n" "$TOKEN"
say "Credentials valid for $((DURATION / 60)) minutes. Next: AWS=1 ./start_local_labs.sh"
