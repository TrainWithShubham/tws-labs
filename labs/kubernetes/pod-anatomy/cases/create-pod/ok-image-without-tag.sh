printf '%s\n' 'apiVersion: v1' 'kind: Pod' 'metadata:' '  name: web-pod' '  labels:' '    app: web' 'spec:' '  containers:' '    - name: nginx' '      image: nginx' > app/pod.yaml
