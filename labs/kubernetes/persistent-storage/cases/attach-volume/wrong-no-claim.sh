sed -i '/image: nginx:1.27/a \      volumes:\n        - name: data-volume\n          emptyDir: {}' app/deployment.yaml

