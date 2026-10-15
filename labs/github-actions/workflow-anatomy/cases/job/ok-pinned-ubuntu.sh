printf '%s\n' 'name: CI' 'on:' '  push:' '    branches: [main]' 'jobs:' '  build:' '    runs-on: ubuntu-22.04' > shop/.github/workflows/ci.yml
