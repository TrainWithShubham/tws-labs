printf '%s\n' 'name: Deploy Pipeline' 'on:' '  push:' '    branches: [main]' 'permissions:' '  contents: read' 'jobs:' '  deploy-staging:' '    uses: ./.github/workflows/deploy.yml' '    steps:' '      - run: echo "deploying"' '    with:' '      environment: staging' '    secrets: inherit' > shop/.github/workflows/main.yml

