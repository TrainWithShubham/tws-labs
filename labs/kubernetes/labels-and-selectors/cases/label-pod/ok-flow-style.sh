sed -i 's|^  name: web-pod$|  name: web-pod\n  labels: {app: web, env: prod}|' app/pod.yaml
