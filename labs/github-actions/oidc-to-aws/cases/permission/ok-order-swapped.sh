printf '%s\n' 'permissions:' '  contents: read' '  id-token: write' | cat - shop/.github/workflows/deploy.yml > /tmp/d.new && cp /tmp/d.new shop/.github/workflows/deploy.yml
