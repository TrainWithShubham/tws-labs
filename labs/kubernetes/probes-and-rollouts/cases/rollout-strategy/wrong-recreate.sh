sed -i 's|^  replicas: 3$|&\n  strategy:\n    type: Recreate|' app/deployment.yaml
