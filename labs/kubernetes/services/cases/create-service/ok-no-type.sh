printf '%s\n' 'apiVersion: v1' 'kind: Service' 'metadata:' '  name: nginx-service' 'spec:' '  selector:' '    app: nginx' '  ports:' '    - port: 80' '      targetPort: 80' > app/service.yaml
