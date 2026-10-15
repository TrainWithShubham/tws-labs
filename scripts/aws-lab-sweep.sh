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

BUCKETS=()
for b in $(aws s3api list-buckets --query 'Buckets[].Name' --output text 2>/dev/null); do
  case "$b" in tws-labs-*) BUCKETS+=("$b") ;; esac
done
VOLUMES=()
for v in $(aws ec2 describe-volumes --filters Name=tag-key,Values=tws-labs --query 'Volumes[].VolumeId' --output text 2>/dev/null); do
  VOLUMES+=("$v")
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
