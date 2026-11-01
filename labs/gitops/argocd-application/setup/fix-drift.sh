sed -i 's|argoproj.io/v1beta1|argoproj.io/v1alpha1|; s|namespace: default$|namespace: argocd|' "$LAB_HOME/checkout-app.yaml"
