mkdir -p app
cat <<'EOF' > app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: app-deployment
spec:
  replicas: 1
  selector:
    matchLabels:
      app: storage-app
  template:
    metadata:
      labels:
        app: storage-app
    spec:
      containers:
        - name: app
          image: nginx:1.27
EOF

