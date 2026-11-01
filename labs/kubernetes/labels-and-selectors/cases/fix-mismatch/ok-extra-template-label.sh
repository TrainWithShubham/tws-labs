sed -i 's|app: web-v1|app: web|' app/deployment.yaml
sed -i 's|^        tier: frontend$|        tier: frontend\n        version: v1|' app/deployment.yaml
