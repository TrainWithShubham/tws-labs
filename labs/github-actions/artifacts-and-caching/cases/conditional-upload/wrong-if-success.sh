printf '%s\n' '      - uses: actions/upload-artifact@v7' '        if: success()' '        with:' '          name: test-reports' '          path: test-results' >> shop/.github/workflows/ci.yml
