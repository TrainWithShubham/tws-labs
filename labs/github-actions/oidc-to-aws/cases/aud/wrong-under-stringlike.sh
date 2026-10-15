jq '.Statement[0].Condition.StringLike["token.actions.githubusercontent.com:aud"] = "sts.amazonaws.com"' shop/trust-policy.json > shop/tp.tmp && mv shop/tp.tmp shop/trust-policy.json
