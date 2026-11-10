printf '%s\n' 'kind: Service' 'apiVersion: v1' 'metadata:' '  name: api-service' '  namespace: development' 'spec:' '  ports:' '    - protocol: TCP' '      port: 8080' '      targetPort: 8080' '  selector:' '    app: api-worker' > app/api-service.yaml

