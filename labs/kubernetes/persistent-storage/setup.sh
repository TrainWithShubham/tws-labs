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
printf 'apiVersion: v1\nkind: PersistentVolumeClaim\nmetadata:\n  name: reports-data\nspec:\n  storageClassName: ""\n  accessModes:\n    - ReadWriteMany\n  resources:\n    requests:\n      storage: 5Gi\n' > app/reports-pvc.yaml
