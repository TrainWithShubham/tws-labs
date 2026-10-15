printf '%s\n' 'apiVersion: v1' 'kind: ConfigMap' 'metadata:' '  name: config' 'data:' '  LOG_LEVEL: debug' '  GREETING: hello' > app/configmap.yaml
