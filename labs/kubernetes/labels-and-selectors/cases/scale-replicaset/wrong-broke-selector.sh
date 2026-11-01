sed -i 's|^  replicas: 1$|  replicas: 3|' app/replicaset.yaml
sed -i 's|^      app: worker$|      app: workers|' app/replicaset.yaml
