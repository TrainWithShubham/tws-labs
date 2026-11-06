printf '%s\n' 'apiVersion: v1' 'kind: Service' 'metadata:' '  name: web-service' '  namespace: development' 'spec:' '  selector:' '    app: web' '  ports:' '    - port: 8080' '      targetPort: 8080' > app/dev-service.yaml

