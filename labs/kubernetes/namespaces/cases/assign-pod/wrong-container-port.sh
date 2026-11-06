sed -i '/metadata:/a \  namespace: development' app/dev-pod.yaml
sed -i 's/containerPort: 80/containerPort: 8080/' app/dev-pod.yaml

