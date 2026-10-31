mkdir -p shop/templates
printf '%s\n' 'replicaCount: "two"' 'image:' '  repository: nginx' '  tag: "1.27.0"' 'service:' '  port: 80' > shop/values.yaml
