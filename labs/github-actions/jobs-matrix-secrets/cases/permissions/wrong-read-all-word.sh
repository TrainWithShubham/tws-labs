printf '%s\n' 'permissions: read-all' | cat - shop/.github/workflows/ci.yml > /tmp/ci.new && cp /tmp/ci.new shop/.github/workflows/ci.yml
