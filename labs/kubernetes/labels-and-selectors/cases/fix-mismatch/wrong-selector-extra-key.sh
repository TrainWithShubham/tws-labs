sed -i 's|app: web-v1|app: web|' app/deployment.yaml
sed -i 's|^      app: web$|      app: web\n      tier: backend|' app/deployment.yaml
