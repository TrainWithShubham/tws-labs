sed -i 's/namespace: default/namespace: development/' app/api-service.yaml
sed -i 's/app: wrong-worker/app: api-worker/' app/api-service.yaml
sed -i 's/port: 8080/port: 80/' app/api-service.yaml

