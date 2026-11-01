sed -i 's|^spec:$|spec:\n  selector:\n    app: web\n    tier: frontend|' app/service.yaml
