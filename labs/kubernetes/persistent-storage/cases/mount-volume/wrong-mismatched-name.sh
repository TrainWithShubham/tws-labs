sed -i '/image: nginx:1.27/a \          volumeMounts:\n            - name: other-volume\n              mountPath: /data' app/deployment.yaml

