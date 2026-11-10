printf '%s\n' 'apiVersion: v1' 'kind: Service' 'metadata:' '  name: web-service' '  namespace: development' 'spec:' '  selector:' '    app: web' '  ports:' '    - port: 80' '      targetPort: 80' > app/dev-service.yaml

