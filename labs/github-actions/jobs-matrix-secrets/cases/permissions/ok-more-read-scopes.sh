printf '%s\n' 'permissions:' '  contents: read' '  pull-requests: read' | cat - shop/.github/workflows/ci.yml > /tmp/ci.new && cp /tmp/ci.new shop/.github/workflows/ci.yml
