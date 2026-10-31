sed -i '/image: nginx:1.27/a \      volumes:\n        - name: custom-vol\n          persistentVolumeClaim:\n            claimName: app-storage' app/deployment.yaml
