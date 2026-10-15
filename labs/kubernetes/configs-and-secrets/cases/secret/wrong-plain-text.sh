printf '%s\n' 'apiVersion: v1' 'kind: Secret' 'metadata:' '  name: db-credentials' 'type: Opaque' 'data:' '  DB_PASSWORD: s3cr3t' > app/secret.yaml
