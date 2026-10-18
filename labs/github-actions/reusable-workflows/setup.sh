mkdir -p shop/scripts shop/.github/workflows

cat > shop/scripts/deploy.sh <<'SH'
#!/bin/bash
set -e
target="${1:-development}"
echo "Deploying shop to: $target"
if [ -n "$DEPLOY_TOKEN" ]; then
  echo "Authenticated with deployment token."
fi
echo "Deployment to $target completed successfully."
SH
chmod +x shop/scripts/deploy.sh

cat > shop/.github/workflows/main.yml <<'YML'
name: Deploy Pipeline
on:
  push:
    branches: [main]
permissions:
  contents: read
jobs:
YML
