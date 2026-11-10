sed -i '/metadata:/a \  namespace: development' app/dev-pod.yaml
sed -i 's/nginx:1.27/nginx/' app/dev-pod.yaml

