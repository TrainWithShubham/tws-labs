printf '%s\n' 'apiVersion: argoproj.io/v1alpha1' 'kind: Application' 'metadata:' '  namespace: argocd' '  name: checkout' 'spec:' '  project: default' > checkout-app.yaml
