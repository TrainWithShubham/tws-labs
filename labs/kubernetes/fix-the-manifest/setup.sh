#!/bin/bash
set -e

mkdir -p app

cat <<'EOF' > app/deployment.yaml
apiVersion: apps/v1beta1
kind: Deployment
metadata:
  name: shop
spec:
  replicas: 2
  selector:
    matchLabels:
      app: shop
  template:
    metadata:
      labels:
        app: shop-web
    spec:
      containers:
        - name: shop
          image: nginx
          ports:
            - containerPort: 8080
EOF

cat <<'EOF' > app/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: shop
spec:
  selector:
    app: shop-web
  ports:
    - port: 80
      targetPort: 80
EOF
