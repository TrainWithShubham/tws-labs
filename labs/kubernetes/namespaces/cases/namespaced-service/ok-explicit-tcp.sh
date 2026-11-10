printf '%s\n' 'apiVersion: v1' 'kind: Service' 'metadata:' '  name: web-service' '  namespace: development' 'spec:' '  type: ClusterIP' '  selector:' '    app: web' '  ports:' '    - protocol: TCP' '      port: 80' '      targetPort: 80' > app/dev-service.yaml

