sed -i 's|^              containerPort: 80$|&\n          startupProbe:\n            httpGet:\n              path: /healthz\n              port: 80|' app/deployment.yaml
