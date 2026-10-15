printf '%s\n' 'apiVersion: v1' 'kind: ConfigMap' 'metadata:' '  name: app-config' 'data:' '  LOG_LEVEL: info' '  GREETING: hello' > app/configmap.yaml
