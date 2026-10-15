#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
f=shop/.github/workflows/ci.yml
grep -q 'strategy:' "$f" || printf '%s\n' '  test:' '    runs-on: ${{ matrix.os }}' '    steps:' '      - uses: actions/checkout@v4' '      - run: npm test' '    strategy:' '      matrix:' '        node: [18, 20, 22]' '        os: [ubuntu-latest, macos-latest]' >> "$f"
