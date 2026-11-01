sed -i '/^  name: web-pod$/a\  labels:\n    app: web\n    env: prod' app/pod.yaml
