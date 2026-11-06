sed -i '/metadata:/a \  namespace: development' app/dev-pod.yaml
sed -i 's/app: web/app: frontend/' app/dev-pod.yaml

