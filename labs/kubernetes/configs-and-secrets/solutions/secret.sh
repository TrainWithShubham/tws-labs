printf '%s\n' 'apiVersion: v1' 'kind: Secret' 'metadata:' '  name: db-credentials' 'type: Opaque' 'data:' "  DB_PASSWORD: $(echo -n s3cr3t | base64)" > app/secret.yaml
