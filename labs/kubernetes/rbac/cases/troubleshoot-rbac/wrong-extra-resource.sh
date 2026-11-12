sed -i 's/- ""/- "apps"/' app/deploy-manager-role.yaml
sed -i '/      - deployments/a\      - secrets' app/deploy-manager-role.yaml
