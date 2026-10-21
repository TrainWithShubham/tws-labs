#!/usr/bin/env bash
# Delete what the AWS labs may have left in YOUR account: S3 buckets named tws-labs-* and EBS volumes tagged tws-labs.
#   scripts/aws-lab-sweep.sh          dry run: lists them, deletes nothing
#   scripts/aws-lab-sweep.sh --yes    deletes them
# Run it on your machine with the same credentials the labs use (see docs/aws-labs.md). It never touches anything else.
set -euo pipefail

say() { printf '%s\n' "$*"; }
die() { printf '%s\n' "$*" >&2; exit 1; }

YES=0
for a in "$@"; do
  case "$a" in
    --yes) YES=1 ;;
    *) die "usage: scripts/aws-lab-sweep.sh [--yes]" ;;
  esac
done

command -v aws >/dev/null 2>&1 || die "The AWS CLI is not installed on this machine."
ARN="$(aws sts get-caller-identity --query Arn --output text 2>/dev/null)" || die "Your AWS credentials are missing or expired (docs/aws-labs.md)."
case "$ARN" in *:root) die "These are root user credentials. Use the tws-labs-learner role (docs/aws-labs.md)." ;; esac
ACCOUNT="$(aws sts get-caller-identity --query Account --output text)"
REGION="${AWS_REGION:-${AWS_DEFAULT_REGION:-}}"
[ -n "$REGION" ] || die "Set AWS_REGION first, so the sweep knows where to look."
say "Account $ACCOUNT, region $REGION"

# A failed listing must stop the sweep: treating it as "nothing there" would report a clean account while billable resources remain.
listed() {
  local out
  out="$("$@" 2>&1)" || die "An AWS call failed, so the sweep cannot tell what is left (${out%%$'\n'*}). Check your credentials, region and permissions (docs/aws-labs.md)."
  printf '%s\n' "$out"
}
# Assigned first, not read in the `for` line: a failure inside $(...) there would not stop the script.
BUCKET_LIST="$(listed aws s3api list-buckets --query 'Buckets[].Name' --output text)"
VOLUME_LIST="$(listed aws ec2 describe-volumes --filters Name=tag-key,Values=tws-labs --query 'Volumes[].VolumeId' --output text)"
BUCKETS=()
for b in $BUCKET_LIST; do
  case "$b" in tws-labs-*) BUCKETS+=("$b") ;; esac
done
VOLUMES=()
for v in $VOLUME_LIST; do
  case "$v" in vol-*) VOLUMES+=("$v") ;; esac
done

if [ "${#BUCKETS[@]}" -eq 0 ] && [ "${#VOLUMES[@]}" -eq 0 ]; then say "Nothing to clean up."; exit 0; fi
for b in ${BUCKETS[@]+"${BUCKETS[@]}"}; do say "  bucket  $b"; done
for v in ${VOLUMES[@]+"${VOLUMES[@]}"}; do say "  volume  $v"; done

if [ "$YES" -ne 1 ]; then say "Dry run: nothing was deleted. Run again with --yes to delete the items above."; exit 0; fi

for b in ${BUCKETS[@]+"${BUCKETS[@]}"}; do
  if aws s3api delete-bucket --bucket "$b" 2>/dev/null; then say "deleted bucket $b"; else say "could not delete bucket $b (is it empty? remove its objects and versions first)"; fi
done
for v in ${VOLUMES[@]+"${VOLUMES[@]}"}; do
  if aws ec2 delete-volume --volume-id "$v" 2>/dev/null; then say "deleted volume $v"; else say "could not delete volume $v (is it still attached?)"; fi
done
