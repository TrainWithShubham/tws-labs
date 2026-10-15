printf '%s\n' 'name: CI' 'on:' '  push:' '    branches: [main]' 'jobs:' '  test:' '    runs-on: ubuntu-latest' > shop/.github/workflows/ci.yml
