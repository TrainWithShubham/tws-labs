sed -i '/image: nginx:1.27/a \          volumeMounts:\n            - name: data-volume\n              mountPath: /data' app/deployment.yaml

