#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
mkdir -p shop/.github/workflows
cat > shop/.github/workflows/deploy.yml <<'YML'
name: Reusable Deploy
on:
  workflow_call:
    inputs:
      environment:
        required: true
        type: string
    secrets:
      deploy-token:
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
          DEPLOY_TOKEN: ${{ secrets.deploy-token }}
YML

cat > shop/.github/workflows/main.yml <<'YML'
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

