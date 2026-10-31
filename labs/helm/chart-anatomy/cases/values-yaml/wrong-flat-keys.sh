mkdir -p shop/templates
printf '%s\n' 'replicaCount: 2' 'image: nginx' 'tag: "1.27.0"' 'port: 80' > shop/values.yaml
