#!/bin/bash
set -e
# Seed the reports the lab works from, and start every session from a clean bucket: the emulator keeps its resources until it restarts,
# so a lab you ran before would otherwise leave tws-labs-notes behind and make the first task look already done.
mkdir -p ~/reports
printf 'quarter,revenue\n2026-q1,100\n' > ~/reports/2026-q1.csv
printf 'quarter,revenue\n2026-q2,120\n' > ~/reports/2026-q2.csv
printf 'quarter,revenue,note\n2026-q1,104,corrected after audit\n' > ~/reports/2026-q1-corrected.csv
b=tws-labs-notes
if command -v aws >/dev/null 2>&1; then
  # A policy from a previous run may deny everything, even listing the bucket, so remove it first (the owner always can).
  aws s3api delete-bucket-policy --bucket "$b" >/dev/null 2>&1 || true
fi
if command -v aws >/dev/null 2>&1 && aws s3api head-bucket --bucket "$b" >/dev/null 2>&1; then
  aws s3api list-object-versions --bucket "$b" --query 'Versions[].[Key,VersionId]' --output text 2>/dev/null |
    while read -r k v; do [ -n "$v" ] && [ "$k" != None ] && aws s3api delete-object --bucket "$b" --key "$k" --version-id "$v" >/dev/null || true; done
  aws s3api list-object-versions --bucket "$b" --query 'DeleteMarkers[].[Key,VersionId]' --output text 2>/dev/null |
    while read -r k v; do [ -n "$v" ] && [ "$k" != None ] && aws s3api delete-object --bucket "$b" --key "$k" --version-id "$v" >/dev/null || true; done
  aws s3api delete-bucket --bucket "$b" >/dev/null
fi
