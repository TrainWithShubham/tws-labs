sed -i '/namespace: default/d' app/monitoring-ns.yaml
printf '%s\n' 'apiVersion: v1' 'kind: ConfigMap' 'metadata:' '  name: app-config' '  namespace: development' > app/app-config.yaml

