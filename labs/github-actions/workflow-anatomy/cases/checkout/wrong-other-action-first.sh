printf '%s\n' 'name: CI' 'on:' '  push:' '    branches: [main]' 'jobs:' '  build:' '    runs-on: ubuntu-latest' '    steps:' '      - uses: actions/setup-node@v4' > shop/.github/workflows/ci.yml
