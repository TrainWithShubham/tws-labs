printf '%s\n' 'apiVersion: v1' 'kind: Pod' 'metadata:' '  name: web-pod' '  labels:' '    app: api' 'spec:' '  containers:' '    - name: nginx' '      image: nginx:1.27' > app/pod.yaml
