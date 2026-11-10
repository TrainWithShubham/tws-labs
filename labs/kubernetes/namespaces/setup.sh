#!/bin/bash
mkdir -p app

cat <<'EOF' > app/dev-pod.yaml
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

cat <<'EOF' > app/api-pod.yaml
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

cat <<'EOF' > app/api-service.yaml
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

cat <<'EOF' > app/monitoring-ns.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: monitoring
  namespace: default
EOF

cat <<'EOF' > app/app-config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  APP_ENV: development
  LOG_LEVEL: debug
EOF
