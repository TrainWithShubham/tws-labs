sed -i 's|^              containerPort: 80$|&\n          readinessProbe:\n            httpGet:\n              path: /ready\n              port: 80\n            periodSeconds: 5|' app/deployment.yaml
