sed -i '/image: nginx:1.27/a \          volumeMounts:\n            - name: data-volume\n              mountPath: /data\n              readOnly: false' app/deployment.yaml

