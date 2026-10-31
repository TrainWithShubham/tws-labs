#!/bin/bash
set -e
mkdir -p app

cat <<'YAML' > app/pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: web-pod
spec:
  containers:
    - name: web
      image: nginx:1.27
YAML

cat <<'YAML' > app/deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web
spec:
  replicas: 2
  selector:
    matchLabels:
      app: web
  template:
    metadata:
      labels:
        app: web-v1
        tier: frontend
    spec:
      containers:
        - name: web
          image: nginx:1.27
          ports:
            - containerPort: 80
YAML

cat <<'YAML' > app/service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  ports:
    - port: 80
      targetPort: 80
YAML

cat <<'YAML' > app/replicaset.yaml
apiVersion: apps/v1
kind: ReplicaSet
metadata:
  name: worker
spec:
  replicas: 1
  selector:
    matchLabels:
      app: worker
  template:
    metadata:
      labels:
        app: worker
    spec:
      containers:
        - name: worker
          image: busybox:1.36
          command: ["sleep", "3600"]
YAML

cat <<'YAML' > app/stray-pod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: worker-debug
  labels:
    app: worker
    purpose: debug
spec:
  containers:
    - name: shell
      image: busybox:1.36
      command: ["sleep", "3600"]
YAML
