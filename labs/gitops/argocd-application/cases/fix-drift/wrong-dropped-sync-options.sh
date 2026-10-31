sed -i '/syncOptions/,$d' checkout-app.yaml
sed -i 's|prune: false|prune: true|; s|selfHeal: false|selfHeal: true|' checkout-app.yaml
