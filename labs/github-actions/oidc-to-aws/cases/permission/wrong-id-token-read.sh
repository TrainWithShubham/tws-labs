printf '%s\n' 'permissions:' '  id-token: read' '  contents: read' | cat - shop/.github/workflows/deploy.yml > /tmp/d.new && cp /tmp/d.new shop/.github/workflows/deploy.yml
