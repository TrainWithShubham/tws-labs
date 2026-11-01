sed -i 's|^spec:$|spec:\n  selector:\n    app: web\n    env: prod|' app/service.yaml
