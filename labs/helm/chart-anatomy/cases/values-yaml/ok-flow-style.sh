mkdir -p shop/templates
printf '%s\n' 'replicaCount: 1' 'image: {repository: nginx, tag: 1.27.0}' 'service: {port: 8080}' > shop/values.yaml
