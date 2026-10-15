printf '%s\n' 'name: CI' 'on:' '  push:' '    branches: [main]' 'jobs:' '  build:' '    runs-on: ubuntu-latest' '    steps:' '      - run: echo hi' > shop/.github/workflows/ci.yml
