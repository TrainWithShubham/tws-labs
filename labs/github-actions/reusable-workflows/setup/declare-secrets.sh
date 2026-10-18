#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p shop/.github/workflows
if [ ! -f shop/.github/workflows/deploy.yml ]; then
cat > shop/.github/workflows/deploy.yml <<'YML'
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
permissions:
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh "${{ inputs.environment }}"
YML
fi
