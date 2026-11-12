#!/bin/bash
set -e
# Skipped ahead: make the bucket tws-labs-notes (and what the earlier tasks would have left in it) so this task can be done on its own.
b=tws-labs-notes
aws s3api head-bucket --bucket "$b" >/dev/null 2>&1 || aws s3api create-bucket --bucket "$b" >/dev/null
