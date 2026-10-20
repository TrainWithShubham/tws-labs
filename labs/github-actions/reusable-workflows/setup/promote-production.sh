#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p shop/.github/workflows
[ -s shop/.github/workflows/deploy.yml ] || cat > shop/.github/workflows/deploy.yml <<'YML'
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      DEPLOY_TOKEN:
        required: false
permissions:
  contents: read
jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - run: ./scripts/deploy.sh "${{ inputs.environment }}"
        env:
          DEPLOY_TOKEN: ${{ secrets.DEPLOY_TOKEN }}
YML

grep -qs 'deploy-staging' shop/.github/workflows/main.yml || cat > shop/.github/workflows/main.yml <<'YML'
name: Deploy Pipeline
on:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
  deploy-staging:
    uses: ./.github/workflows/deploy.yml
    with:
      environment: staging
    secrets: inherit
YML

