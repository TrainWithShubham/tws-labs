sed -i 's/namespace: default/namespace: development/' app/api-service.yaml
sed -i 's/app: wrong-worker/app: api-worker/' app/api-service.yaml

