printf '%s\n' '        env:' '          API_TOKEN: ${{ secrets.API_TOKEN }}' '          DEPLOY_ENV: prod' >> shop/.github/workflows/ci.yml
