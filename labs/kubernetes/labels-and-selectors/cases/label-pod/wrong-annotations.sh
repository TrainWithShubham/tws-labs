sed -i '/^  name: web-pod$/a\  annotations:\n    app: web\n    env: prod' app/pod.yaml
