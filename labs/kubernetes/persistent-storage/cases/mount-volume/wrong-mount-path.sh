sed -i '/image: nginx:1.27/a \          volumeMounts:\n            - name: data-volume\n              mountPath: /var/data' app/deployment.yaml

