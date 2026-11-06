printf '%s\n' 'apiVersion: v1' 'kind: Namespace' 'metadata:' '  name: production' > app/prod-ns.yaml
printf '%s\n' 'apiVersion: v1' 'kind: Pod' 'metadata:' '  name: web-backend' '  namespace: production' '  labels:' '    app: web' 'spec:' '  containers:' '    - name: nginx' '      image: nginx:1.27' '      ports:' '        - containerPort: 8080' > app/prod-pod.yaml

