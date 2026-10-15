printf '%s\n' 'apiVersion: v1' 'kind: Pod' 'metadata:' '  name: web' '  labels:' '    app: web' 'spec:' '  containers:' '    - name: nginx' '      image: nginx:1.27' > app/pod.yaml
