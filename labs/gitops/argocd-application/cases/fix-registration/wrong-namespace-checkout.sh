sed -i 's|argoproj.io/v1beta1|argoproj.io/v1alpha1|' checkout-app.yaml
sed -i '0,/namespace: default/s||namespace: checkout|' checkout-app.yaml
