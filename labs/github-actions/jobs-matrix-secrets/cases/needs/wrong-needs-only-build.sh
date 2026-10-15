printf '%s\n' '  deploy:' '    needs: [build]' '    runs-on: ubuntu-latest' '    steps:' '      - run: ./deploy.sh' >> shop/.github/workflows/ci.yml
