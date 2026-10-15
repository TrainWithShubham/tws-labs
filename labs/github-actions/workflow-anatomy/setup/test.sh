#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
f=shop/.github/workflows/ci.yml
mkdir -p shop/.github/workflows
if [ ! -s "$f" ]; then
  printf '%s\n' 'name: CI' 'on:' '  push:' '    branches: [main]' 'jobs:' '  build:' '    runs-on: ubuntu-latest' > "$f"
fi
grep -q 'steps:' "$f" || printf '%s\n' '    steps:' >> "$f"
grep -q 'actions/checkout' "$f" || printf '%s\n' '      - uses: actions/checkout@v4' >> "$f"
