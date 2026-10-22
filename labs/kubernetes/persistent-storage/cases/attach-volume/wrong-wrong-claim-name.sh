sed -i '/image: nginx:1.27/a \      volumes:\n        - name: data-volume\n          persistentVolumeClaim:\n            claimName: wrong-claim' app/deployment.yaml

