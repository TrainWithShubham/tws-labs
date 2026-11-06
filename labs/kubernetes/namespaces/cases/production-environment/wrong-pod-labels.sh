printf '%s\n' 'apiVersion: v1' 'kind: Namespace' 'metadata:' '  name: production' > app/prod-ns.yaml
printf '%s\n' 'apiVersion: v1' 'kind: Pod' 'metadata:' '  name: web-backend' '  namespace: production' '  labels:' '    app: api' 'spec:' '  containers:' '    - name: nginx' '      image: nginx:1.27' '      ports:' '        - containerPort: 80' > app/prod-pod.yaml

