sed -i 's/- ""/- "apps"/' app/deploy-manager-role.yaml
printf '%s\n' '  - apiGroups: ["apps"]' '    resources: ["secrets"]' '    verbs: ["get"]' >> app/deploy-manager-role.yaml
