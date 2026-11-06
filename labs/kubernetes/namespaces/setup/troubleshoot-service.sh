mkdir -p app
[ -f app/api-pod.yaml ] || cat <<'EOF' > app/api-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: api-worker
  namespace: development
  labels:
    app: api-worker
spec:
  containers:
    - name: worker
      image: nginx:1.27
      ports:
        - containerPort: 8080
EOF

[ -f app/api-service.yaml ] || cat <<'EOF' > app/api-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api-service
  namespace: default
spec:
  selector:
    app: wrong-worker
  ports:
    - port: 8080
      targetPort: 8080
EOF

