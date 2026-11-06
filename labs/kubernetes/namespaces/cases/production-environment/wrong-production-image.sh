printf '%s\n' 'apiVersion: v1' 'kind: Namespace' 'metadata:' '  name: production' > app/prod-ns.yaml
printf '%s\n' 'apiVersion: v1' 'kind: Pod' 'metadata:' '  name: web-backend' '  namespace: production' '  labels:' '    app: web' 'spec:' '  containers:' '    - name: nginx' '      image: httpd:alpine' '      ports:' '        - containerPort: 80' > app/prod-pod.yaml

