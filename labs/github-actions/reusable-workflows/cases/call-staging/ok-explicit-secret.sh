printf '%s\n' 'name: Deploy Pipeline' 'on:' '  push:' '    branches: [main]' 'permissions:' '  contents: read' 'jobs:' '  deploy-staging:' '    uses: ./.github/workflows/deploy.yml' '    with:' '      environment: staging' '    secrets:' '      deploy-token: ${{ secrets.DEPLOY_TOKEN }}' > shop/.github/workflows/main.yml

