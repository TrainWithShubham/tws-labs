jq '.Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:sub"] = "repo:acme-corp/*"' shop/trust-policy.json > shop/tp.tmp && mv shop/tp.tmp shop/trust-policy.json
