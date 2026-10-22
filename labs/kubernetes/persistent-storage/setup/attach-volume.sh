mkdir -p app
[ -s app/pv.yaml ] || printf 'apiVersion: v1\nkind: PersistentVolume\nmetadata:\n  name: local-pv\nspec:\n  storageClassName: ""\n  capacity:\n    storage: 1Gi\n  accessModes:\n    - ReadWriteOnce\n  persistentVolumeReclaimPolicy: Retain\n  hostPath:\n    path: /mnt/data\n' > app/pv.yaml
[ -s app/pvc.yaml ] || printf 'apiVersion: v1\nkind: PersistentVolumeClaim\nmetadata:\n  name: app-storage\nspec:\n  storageClassName: ""\n  accessModes:\n    - ReadWriteOnce\n  resources:\n    requests:\n      storage: 1Gi\n' > app/pvc.yaml
[ -f app/deployment.yaml ] || cat <<'EOF' > app/deployment.yaml
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
