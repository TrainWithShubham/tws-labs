sed -i 's|^      containers:$|      readinessProbe:\n        httpGet:\n          path: /ready\n          port: 80\n        periodSeconds: 5\n      containers:|' app/deployment.yaml
