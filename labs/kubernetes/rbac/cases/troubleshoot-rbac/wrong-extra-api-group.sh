sed -i 's/- ""/- "apps"/' app/deploy-manager-role.yaml
sed -i '/- "apps"/a\      - "batch"' app/deploy-manager-role.yaml
