sed -i '/syncPolicy/,$d' checkout-app.yaml
printf '%s\n' '  syncPolicy:' '    syncOptions:' '      - CreateNamespace=true' '    automated:' '      selfHeal: true' '      prune: true' >> checkout-app.yaml
