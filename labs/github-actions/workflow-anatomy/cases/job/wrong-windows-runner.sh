printf '%s\n' 'name: CI' 'on:' '  push:' '    branches: [main]' 'jobs:' '  build:' '    runs-on: windows-latest' > shop/.github/workflows/ci.yml
