printf '%s\n' '# Production environment namespace' 'kind: Namespace' 'apiVersion: v1' 'metadata:' '  name: production' > app/prod-ns.yaml
printf '%s\n' '# Production backend Pod' 'kind: Pod' 'apiVersion: v1' 'metadata:' '  name: web-backend' '  namespace: production' '  labels:' '    app: web' 'spec:' '  containers:' '    - name: nginx' '      image: nginx:1.27' '      ports:' '        - containerPort: 80' > app/prod-pod.yaml

