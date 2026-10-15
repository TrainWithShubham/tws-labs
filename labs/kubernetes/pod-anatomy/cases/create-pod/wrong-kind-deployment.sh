printf '%s\n' 'apiVersion: apps/v1' 'kind: Deployment' 'metadata:' '  name: web-pod' '  labels:' '    app: web' 'spec:' '  containers:' '    - name: nginx' '      image: nginx:1.27' > app/pod.yaml
