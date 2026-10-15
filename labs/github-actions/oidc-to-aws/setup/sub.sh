#!/bin/bash
# Starting state if you skipped ahead. Safe to run again: it only fills in what is missing.
f=shop/trust-policy.json
[ "$(jq -r '.Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] // ""' "$f")" = sts.amazonaws.com ] || { jq '.Statement[0].Condition.StringEquals["token.actions.githubusercontent.com:aud"] = "sts.amazonaws.com"' "$f" > shop/tp.tmp && mv shop/tp.tmp "$f"; }
