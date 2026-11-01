sed -i 's|argoproj.io/v1beta1|argoproj.io/v1alpha1|' checkout-app.yaml
sed -i 's|namespace: default|namespace: argocd|' checkout-app.yaml
