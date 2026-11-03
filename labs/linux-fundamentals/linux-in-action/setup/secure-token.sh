#!/bin/bash
mkdir -p config
[ -f config/auth.token ] || echo "sec_tok_prod_99f82d11b3e7a04c" > config/auth.token
chmod 644 config/auth.token
