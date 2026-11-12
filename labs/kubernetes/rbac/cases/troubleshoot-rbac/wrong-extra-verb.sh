sed -i 's/- ""/- "apps"/' app/deploy-manager-role.yaml
sed -i '/      - create/a\      - delete' app/deploy-manager-role.yaml
