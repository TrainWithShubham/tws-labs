#!/bin/bash
set -e

mkdir -p app

cat <<'YAML' > app/web-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: web
spec:
  selector:
    app: web
  ports:
    - name: http
      port: 80
      targetPort: 80
YAML

cat <<'YAML' > app/api-service.yaml
apiVersion: v1
kind: Service
metadata:
  name: api
spec:
  selector:
    app: api
  ports:
    - name: http-api
      port: 8080
      targetPort: 8080
YAML

cat <<'YAML' > app/tls-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: shop-tls
type: kubernetes.io/tls
data:
  tls.crt: ZHVtbXk=
  tls.key: ZHVtbXk=
YAML

cat <<'YAML' > app/blog-ingress.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: blog
spec:
  ingressClassName: public
  rules:
    - host: blog.example.com
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: web
                port:
                  number: 8080
          - path: /api
            pathType: Prefix
            backend:
              service:
                name: apii
                port:
                  number: 8080
YAML
