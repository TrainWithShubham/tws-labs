printf '%s\n' '  deploy:' '    needs: [build, test, lint]' '    runs-on: ubuntu-latest' '    steps:' '      - run: ./deploy.sh' >> shop/.github/workflows/ci.yml
