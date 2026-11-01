sed -i 's|^              containerPort: 80$|&\n          readinessProbe:\n            tcpSocket:\n              port: 80\n            periodSeconds: 5|' app/deployment.yaml
