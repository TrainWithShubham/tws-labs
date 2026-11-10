mkdir -p app
[ -f app/development-ns.yaml ] || cat <<'EOF' > app/development-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: development
EOF

[ -f app/dev-pod.yaml ] || cat <<'EOF' > app/dev-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-backend
  namespace: development
  labels:
    app: web
spec:
  containers:
    - name: nginx
      image: nginx:1.27
      ports:
        - containerPort: 80
EOF

