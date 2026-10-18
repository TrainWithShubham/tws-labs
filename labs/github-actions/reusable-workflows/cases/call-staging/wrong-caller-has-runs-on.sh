printf '%s\n' 'name: Deploy Pipeline' 'on:' '  push:' '    branches: [main]' 'permissions:' '  contents: read' 'jobs:' '  deploy-staging:' '    uses: ./.github/workflows/deploy.yml' '    runs-on: ubuntu-latest' '    with:' '      environment: staging' '    secrets: inherit' > shop/.github/workflows/main.yml

