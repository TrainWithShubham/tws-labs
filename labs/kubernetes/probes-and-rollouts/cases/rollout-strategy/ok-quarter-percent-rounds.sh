sed -i 's|^  replicas: 3$|&\n  strategy:\n    type: RollingUpdate\n    rollingUpdate:\n      maxUnavailable: 25%\n      maxSurge: 25%|' app/deployment.yaml
