printf '%s\n' 'apiVersion: v1' 'kind: Secret' 'metadata:' '  name: db-credentials' 'type: Opaque' 'stringData:' '  DB_PASSWORD: s3cr3t' > app/secret.yaml
