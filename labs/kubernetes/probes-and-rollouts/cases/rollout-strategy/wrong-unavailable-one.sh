sed -i 's|^  replicas: 3$|&\n  strategy:\n    type: RollingUpdate\n    rollingUpdate:\n      maxUnavailable: 1\n      maxSurge: 1|' app/deployment.yaml
