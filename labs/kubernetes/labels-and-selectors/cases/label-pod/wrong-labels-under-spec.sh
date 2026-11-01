sed -i 's|^spec:$|spec:\n  labels:\n    app: web\n    env: prod|' app/pod.yaml
