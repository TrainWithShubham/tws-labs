sed -i 's|^              containerPort: 80$|&\n          resources:\n            limits:\n              cpu: 500m\n              memory: 256Mi|' app/deployment.yaml
