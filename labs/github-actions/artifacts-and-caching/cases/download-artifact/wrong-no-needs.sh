printf '%s\n' '  deploy:' '    runs-on: ubuntu-latest' '    steps:' '      - uses: actions/download-artifact@v8' '        with:' '          name: dist-files' >> shop/.github/workflows/ci.yml
