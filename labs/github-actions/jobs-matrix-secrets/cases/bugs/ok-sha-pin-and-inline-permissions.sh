sed -i 's/^permissions: write-all/permissions: {contents: read}/' shop/.github/workflows/broken.yml
sed -i 's|acme/deploy@main|acme/deploy@0123456789abcdef0123456789abcdef01234567|' shop/.github/workflows/broken.yml
sed -i 's|^      - run: echo .*|      - run: ./release.sh|' shop/.github/workflows/broken.yml
