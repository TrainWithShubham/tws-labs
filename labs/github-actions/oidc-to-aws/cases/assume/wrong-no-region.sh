printf '%s\n' '      - uses: aws-actions/configure-aws-credentials@v4' '        with:' '          role-to-assume: arn:aws:iam::123456789012:role/shop-deploy' >> shop/.github/workflows/deploy.yml
