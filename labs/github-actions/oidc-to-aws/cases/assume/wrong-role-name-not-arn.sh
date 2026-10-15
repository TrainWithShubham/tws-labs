printf '%s\n' '      - uses: aws-actions/configure-aws-credentials@v4' '        with:' '          role-to-assume: shop-deploy' '          aws-region: us-east-1' >> shop/.github/workflows/deploy.yml
