printf '%s\n' '      - uses: actions/upload-artifact@v7' '        if: ${{ always() }}' '        with:' '          name: test-reports' '          path: test-results' >> shop/.github/workflows/ci.yml
