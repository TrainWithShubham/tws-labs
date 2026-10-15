printf '%s\n' '      - uses: actions/cache@v6' '        with:' '          path: dist' '          key: k' '      - run: npm run build' '      - run: npm test' >> shop/.github/workflows/ci.yml
