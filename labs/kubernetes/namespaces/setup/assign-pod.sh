mkdir -p app
[ -f app/dev-pod.yaml ] || cat <<'EOF' > app/dev-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-backend
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
EOF

