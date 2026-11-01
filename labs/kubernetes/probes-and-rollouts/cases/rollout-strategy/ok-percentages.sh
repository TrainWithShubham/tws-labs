sed -i 's|^  replicas: 3$|&\n  strategy:\n    type: RollingUpdate\n    rollingUpdate:\n      maxUnavailable: 0%\n      maxSurge: 34%|' app/deployment.yaml
